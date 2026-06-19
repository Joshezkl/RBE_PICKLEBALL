<?php

namespace App\Services;

use App\Models\ChallengeCourtTeam;
use App\Models\Court;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;
use App\Support\MatchMode;
use Illuminate\Support\Facades\DB;

class CourtService
{
    public function __construct(
        private QueueService $queueService,
        private PairingService $pairingService,
        private MatchService $matchService,
        private MatchModeService $matchModeService,
        private ChallengeCourtService $challengeCourtService,
    ) {}

    public function assignNextUp(PlaySession $session, Court $court): bool
    {
        $session->refresh();
        $court->refresh();

        if ($court->status !== 'available') {
            throw new \RuntimeException('Court is not available');
        }

        if ($court->is_challenge_court) {
            throw new \RuntimeException('Use Challenge Court assignment for this court');
        }

        $playerIds = $this->resolveNextUpPlayerIds($session, $court);
        if (count($playerIds) < $session->groupSize()) {
            return false;
        }

        $this->manualAssign($session, $court, $playerIds);

        return true;
    }

    public function tryAutoAssignAvailableCourts(PlaySession $session): void
    {
        if (! $session->auto_assign_enabled) {
            return;
        }

        $session->refresh();

        $courts = Court::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'available')
            ->where('is_challenge_court', false)
            ->orderBy('court_number')
            ->get();

        foreach ($courts as $court) {
            try {
                if (! $this->assignNextUp($session->fresh(), $court)) {
                    break;
                }
            } catch (\InvalidArgumentException|\RuntimeException) {
                break;
            }
        }
    }

    /**
     * @return list<int>
     */
    private function resolveNextUpPlayerIds(PlaySession $session, Court $court): array
    {
        $groupSize = $session->groupSize();
        $queueType = $this->resolveQueueTypeForCourt($session, $court);

        if ($queueType === null) {
            return [];
        }

        return $this->collectNextAvailablePlayerIds($session, $queueType, $groupSize);
    }

    /**
     * @return list<int>
     */
    private function collectNextAvailablePlayerIds(
        PlaySession $session,
        string $queueType,
        int $count,
    ): array {
        $entries = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->with('player')
            ->get();

        $playerIds = [];

        foreach ($entries as $entry) {
            $player = $entry->player;

            if ($player->availability !== 'active') {
                continue;
            }

            if ($this->challengeCourtService->isPlayerInChallengeCourt($session, $player->id)) {
                continue;
            }

            $playerIds[] = $player->id;

            if (count($playerIds) >= $count) {
                break;
            }
        }

        return $playerIds;
    }

    private function resolveQueueTypeForCourt(PlaySession $session, Court $court): ?string
    {
        return $this->resolveQueueTypeForCourtWithDepth($session, $court, $session->groupSize());
    }

    private function resolveQueueTypeForCourtWithDepth(
        PlaySession $session,
        Court $court,
        int $requiredDepth,
    ): ?string {
        if (MatchMode::usesSkillQueues($session->match_mode)) {
            if ($session->match_mode === MatchMode::SKILL_COURTS && $court->skill_bracket) {
                return $this->queueService->queueDepth($session, $court->skill_bracket) >= $requiredDepth
                    ? $court->skill_bracket
                    : null;
            }

            foreach (MatchMode::SKILL_LEVELS as $skill) {
                if ($this->queueService->queueDepth($session, $skill) >= $requiredDepth) {
                    return $skill;
                }
            }

            return null;
        }

        $nextQueue = $session->next_court_queue;
        $order = $nextQueue === 'winner'
            ? ['winner', 'loser']
            : ['loser', 'winner'];

        foreach ($order as $type) {
            if ($this->queueService->queueDepth($session, $type) >= $requiredDepth) {
                return $type;
            }
        }

        return null;
    }

    /**
     * @param  array<int, int>  $playerIds
     */
    public function manualAssign(PlaySession $session, Court $court, array $playerIds): void
    {
        $groupSize = $session->groupSize();
        if (count($playerIds) !== $groupSize) {
            throw new \InvalidArgumentException("Exactly {$groupSize} players are required");
        }

        if ($court->status !== 'available') {
            throw new \RuntimeException('Court is not available');
        }

        if ($court->is_challenge_court) {
            throw new \RuntimeException('Use Challenge Court assignment for this court');
        }

        $uniqueIds = array_values(array_unique($playerIds));
        if (count($uniqueIds) !== $groupSize) {
            throw new \InvalidArgumentException('All players must be different');
        }

        $players = Player::query()
            ->where('play_session_id', $session->id)
            ->whereIn('id', $uniqueIds)
            ->get();

        if ($players->count() !== $groupSize) {
            throw new \InvalidArgumentException('One or more players not found in session');
        }

        if ($session->match_mode === 'skill_courts' && $court->skill_bracket) {
            foreach ($players as $player) {
                if ($player->skill_level !== $court->skill_bracket) {
                    throw new \InvalidArgumentException(
                        "Court {$court->court_number} is assigned to {$court->skill_bracket} players only"
                    );
                }
            }
        }

        foreach ($players as $player) {
            if ($player->availability !== 'active') {
                throw new \InvalidArgumentException("{$player->name} is stepped out and cannot be assigned");
            }

            if ($this->challengeCourtService->isPlayerInChallengeCourt($session, $player->id)) {
                throw new \InvalidArgumentException("{$player->name} is in Challenge Court");
            }

            $onCourt = Court::query()
                ->where('play_session_id', $session->id)
                ->where('status', '!=', 'available')
                ->whereHas('currentMatch', function ($query) use ($player) {
                    $query->where(function ($q) use ($player) {
                        $q->where('team_a_player1', $player->id)
                            ->orWhere('team_a_player2', $player->id)
                            ->orWhere('team_b_player1', $player->id)
                            ->orWhere('team_b_player2', $player->id);
                    })->where('status', 'in_match');
                })
                ->exists();

            if ($onCourt) {
                throw new \RuntimeException("Player {$player->name} is already on a court");
            }
        }

        QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->whereIn('player_id', $uniqueIds)
            ->delete();

        foreach (['winner', 'loser'] as $type) {
            $this->reindexAfterManualRemove($session, $type);
        }

        foreach (MatchMode::SKILL_LEVELS as $skill) {
            $this->reindexAfterManualRemove($session, $skill);
        }

        $teams = $this->pairingService->formTeams($players, $session);
        $this->matchService->createMatch($session, $court, $teams);

        if (! MatchMode::usesSkillQueues($session->match_mode)) {
            $session->update([
                'next_court_queue' => $session->next_court_queue === 'winner' ? 'loser' : 'winner',
            ]);
        }
    }

    private function reindexAfterManualRemove(PlaySession $session, string $queueType): void
    {
        $entries = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->get();

        foreach ($entries as $index => $entry) {
            $entry->update(['position' => $index + 1]);
        }
    }

    public function removePlayerFromCourt(PlaySession $session, Court $court, Player $player): void
    {
        $session->refresh();
        $court->refresh();

        if ($court->play_session_id !== $session->id) {
            throw new \InvalidArgumentException('Court not in this session');
        }

        if ($court->status !== 'in_match' || ! $court->current_match_id) {
            throw new \RuntimeException('Court has no active match');
        }

        $match = MatchGame::query()->findOrFail($court->current_match_id);

        if ($match->status !== 'in_match') {
            throw new \RuntimeException('Match is not active');
        }

        if ($player->play_session_id !== $session->id) {
            throw new \InvalidArgumentException('Player not in this session');
        }

        if (! $this->playerIsInMatch($match, $player->id)) {
            throw new \InvalidArgumentException('Player is not on this court');
        }

        $slotField = $this->findPlayerSlot($match, $player->id);
        $replacement = $this->takeNextReplacementPlayer($session, $court, $player->id);

        if ($replacement === null) {
            throw new \RuntimeException('No players available in queue to replace removed player');
        }

        $this->returnPlayerToWaitingQueueAtEnd($session, $player);
        $match->update([$slotField => $replacement->id]);
    }

    private function findPlayerSlot(MatchGame $match, int $playerId): string
    {
        return match (true) {
            $match->team_a_player1 === $playerId => 'team_a_player1',
            $match->team_a_player2 === $playerId => 'team_a_player2',
            $match->team_b_player1 === $playerId => 'team_b_player1',
            $match->team_b_player2 === $playerId => 'team_b_player2',
            default => throw new \InvalidArgumentException('Player slot not found on match'),
        };
    }

    private function takeNextReplacementPlayer(
        PlaySession $session,
        Court $court,
        int $removedPlayerId,
    ): ?Player {
        $queueType = $this->resolveQueueTypeForCourtWithDepth($session, $court, 1);

        if ($queueType === null) {
            return null;
        }

        foreach ($this->collectNextAvailablePlayerIds($session, $queueType, 1) as $playerId) {
            if ($playerId === $removedPlayerId) {
                continue;
            }

            $replacement = Player::query()
                ->where('play_session_id', $session->id)
                ->where('id', $playerId)
                ->first();

            if ($replacement === null) {
                continue;
            }

            if ($this->playerIsOnActiveCourt($session, $replacement->id)) {
                throw new \RuntimeException("{$replacement->name} is already on another court");
            }

            QueueEntry::query()
                ->where('play_session_id', $session->id)
                ->where('player_id', $replacement->id)
                ->delete();

            $this->reindexAfterManualRemove($session, $queueType);

            return $replacement;
        }

        return null;
    }

    private function playerIsOnActiveCourt(PlaySession $session, int $playerId): bool
    {
        return Court::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->whereHas('currentMatch', function ($query) use ($playerId) {
                $query->where('status', 'in_match')
                    ->where(function ($q) use ($playerId) {
                        $q->where('team_a_player1', $playerId)
                            ->orWhere('team_a_player2', $playerId)
                            ->orWhere('team_b_player1', $playerId)
                            ->orWhere('team_b_player2', $playerId);
                    });
            })
            ->exists();
    }

    private function playerIsInMatch(MatchGame $match, int $playerId): bool
    {
        return in_array($playerId, [
            $match->team_a_player1,
            $match->team_a_player2,
            $match->team_b_player1,
            $match->team_b_player2,
        ], true);
    }

    private function returnPlayerToWaitingQueueAtEnd(PlaySession $session, Player $player): void
    {
        if (MatchMode::usesSkillQueues($session->match_mode)) {
            $queueType = $player->skill_level ?? MatchMode::SKILL_LEVELS[0];
            $this->queueService->enqueueAtEnd($session, $player, $queueType);

            return;
        }

        $this->queueService->enqueueAtEnd($session, $player, 'loser');
    }

    public function resizeCourtCount(PlaySession $session, int $courtCount): void
    {
        if (! $session->isActive()) {
            throw new \RuntimeException('Session is not active');
        }

        $courtCount = max(1, min(12, $courtCount));
        $currentCount = (int) $session->court_count;

        if ($courtCount === $currentCount) {
            return;
        }

        DB::transaction(function () use ($session, $courtCount, $currentCount) {
            $this->clearAllActiveCourtMatches($session->fresh());

            if ($courtCount < $currentCount) {
                $courtsToRemove = Court::query()
                    ->where('play_session_id', $session->id)
                    ->where('court_number', '>', $courtCount)
                    ->orderByDesc('court_number')
                    ->get();

                foreach ($courtsToRemove as $court) {
                    $this->releaseChallengeCourtTeamsOnCourt($session, $court);
                    $court->delete();
                }

                $remainingCcNumbers = array_values(array_filter(
                    $this->challengeCourtService->courtNumbers($session),
                    fn (int $number) => $number <= $courtCount,
                ));
                $this->challengeCourtService->configureCourts($session, $remainingCcNumbers);
            } else {
                for ($number = $currentCount + 1; $number <= $courtCount; $number++) {
                    Court::query()->create([
                        'play_session_id' => $session->id,
                        'court_number' => $number,
                        'status' => 'available',
                    ]);
                }
            }

            $session->update(['court_count' => $courtCount]);
            $this->matchModeService->configureSession($session->fresh());
            $this->tryAutoAssignAvailableCourts($session->fresh());
            $this->challengeCourtService->tryAutoAssign($session->fresh());
        });
    }

    public function clearAllActiveCourtMatches(PlaySession $session): void
    {
        $courts = Court::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->orderBy('court_number')
            ->get();

        foreach ($courts as $court) {
            $this->clearActiveCourtMatch($session, $court);
        }
    }

    private function clearActiveCourtMatch(PlaySession $session, Court $court): void
    {
        if ($court->status !== 'in_match' || ! $court->current_match_id) {
            return;
        }

        $match = MatchGame::query()->find($court->current_match_id);

        if ($match === null || $match->status !== 'in_match') {
            $court->update([
                'status' => 'available',
                'current_match_id' => null,
            ]);

            return;
        }

        if ($match->is_challenge_court) {
            $this->challengeCourtService->abortActiveMatch($session, $match);
        } else {
            foreach ($this->playersInMatch($match) as $player) {
                $this->returnPlayerToWaitingQueueAtEnd($session, $player);
            }

            $match->delete();
        }

        $court->update([
            'status' => 'available',
            'current_match_id' => null,
        ]);
    }

    /**
     * @return list<Player>
     */
    private function playersInMatch(MatchGame $match): array
    {
        $playerIds = array_values(array_filter([
            $match->team_a_player1,
            $match->team_a_player2,
            $match->team_b_player1,
            $match->team_b_player2,
        ]));

        return Player::query()
            ->whereIn('id', $playerIds)
            ->get()
            ->all();
    }

    private function releaseChallengeCourtTeamsOnCourt(PlaySession $session, Court $court): void
    {
        $teams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('court_id', $court->id)
            ->get();

        if ($teams->isEmpty()) {
            return;
        }

        $nextPosition = (int) (ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->max('position') ?? 0);

        foreach ($teams as $team) {
            $nextPosition++;
            $team->update([
                'status' => ChallengeCourtTeam::STATUS_QUEUED,
                'cc_wins' => 0,
                'court_id' => null,
                'current_match_id' => null,
                'position' => $nextPosition,
            ]);
        }
    }
}
