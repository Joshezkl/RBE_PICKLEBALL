<?php

namespace App\Services;

use App\Models\Court;
use App\Models\PlaySession;
use App\Models\Player;
use App\Support\MatchMode;

class MatchModeService
{
    private const NEW_PLAYER_PAIR_SIZE = 2;

    public function resolvePlayFormat(string $matchMode, ?string $requestedFormat): string
    {
        if (MatchMode::forcesSingles($matchMode)) {
            return 'singles';
        }

        return in_array($requestedFormat, ['doubles', 'singles'], true)
            ? $requestedFormat
            : 'doubles';
    }

    public function configureSession(PlaySession $session): void
    {
        if ($session->match_mode !== MatchMode::SKILL_COURTS) {
            return;
        }

        $brackets = MatchMode::SKILL_LEVELS;
        $courts = Court::query()
            ->where('play_session_id', $session->id)
            ->orderBy('court_number')
            ->get();

        foreach ($courts as $index => $court) {
            $court->update([
                'skill_bracket' => $brackets[$index % count($brackets)],
            ]);
        }
    }

    /**
     * @return list<string>
     */
    public function queueTypesFor(PlaySession $session): array
    {
        if (MatchMode::usesSkillQueues($session->match_mode)) {
            return MatchMode::SKILL_LEVELS;
        }

        return ['winner', 'loser'];
    }

    public function routeNewPlayer(PlaySession $session, Player $player): string
    {
        if (MatchMode::usesSkillQueues($session->match_mode)) {
            $skill = $player->skill_level;
            if (! in_array($skill, MatchMode::SKILL_LEVELS, true)) {
                throw new \InvalidArgumentException('Skill level is required for this match mode');
            }

            return $skill;
        }

        $index = (int) $session->new_players_joined_count;
        $queueType = $this->queueForNewPlayerIndex($index);
        $nextIndex = $index + 1;

        $session->update([
            'new_players_joined_count' => $nextIndex,
            'next_new_player_queue' => $this->queueForNewPlayerIndex($nextIndex),
        ]);

        return $queueType;
    }

    public function queueForNewPlayerIndex(int $index): string
    {
        return intdiv($index, self::NEW_PLAYER_PAIR_SIZE) % 2 === 0
            ? 'winner'
            : 'loser';
    }

    public function requiresSkillLevel(string $matchMode): bool
    {
        return MatchMode::usesSkillQueues($matchMode);
    }

    public function requiresGender(string $matchMode): bool
    {
        return $matchMode === MatchMode::MIXED_DOUBLES;
    }

    /**
     * @param  list<int>  $winnerIds
     * @param  list<int>  $loserIds
     */
    public function enqueueAfterMatch(
        PlaySession $session,
        QueueService $queueService,
        array $winnerIds,
        array $loserIds,
        int $courtNumber,
    ): void {
        if ($session->match_mode === MatchMode::KING_QUEEN_COURT) {
            $this->enqueueKingQueen($session, $queueService, $winnerIds, $loserIds, $courtNumber);

            return;
        }

        if (MatchMode::usesSkillQueues($session->match_mode)) {
            foreach ($winnerIds as $playerId) {
                $player = Player::query()->findOrFail($playerId);
                $queueService->enqueue($session, $player, $player->skill_level ?? 'beginner');
            }
            foreach ($loserIds as $playerId) {
                $player = Player::query()->findOrFail($playerId);
                $queueService->enqueue($session, $player, $player->skill_level ?? 'beginner');
            }

            return;
        }

        $queueService->enqueueWinners($session, $winnerIds);
        $queueService->enqueueLosers($session, $loserIds);
    }

    /**
     * @param  list<int>  $winnerIds
     * @param  list<int>  $loserIds
     */
    private function enqueueKingQueen(
        PlaySession $session,
        QueueService $queueService,
        array $winnerIds,
        array $loserIds,
        int $courtNumber,
    ): void {
        $courtCount = $session->court_count;

        foreach ($winnerIds as $playerId) {
            $player = Player::query()->findOrFail($playerId);
            if ($courtNumber > 1) {
                $queueService->enqueueAtFront($session, $player, 'winner');
            } else {
                $queueService->enqueue($session, $player, 'winner');
            }
        }

        foreach ($loserIds as $playerId) {
            $player = Player::query()->findOrFail($playerId);
            if ($courtNumber < $courtCount) {
                $queueService->enqueue($session, $player, 'loser');
            } else {
                $queueService->enqueueAtEnd($session, $player, 'loser');
            }
        }
    }

    public function primaryQueueType(PlaySession $session): string
    {
        $types = $this->queueTypesFor($session);

        if (MatchMode::usesSkillQueues($session->match_mode)) {
            return $types[0];
        }

        return $session->next_court_queue;
    }
}
