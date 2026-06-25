<?php

namespace App\Services;

use App\Models\ChallengeCourtTeam;
use App\Models\Court;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;
use App\Support\MatchMode;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class ChallengeCourtService
{
    public function __construct(
        private QueueService $queueService,
        private MatchModeService $matchModeService,
        private MatchService $matchService,
    ) {}

    /**
     * @return list<int>
     */
    public function courtNumbers(PlaySession $session): array
    {
        $settings = $session->match_mode_settings ?? [];

        if (! array_key_exists('challenge_court_numbers', $settings)) {
            return [1];
        }

        return array_values(array_map(
            'intval',
            $settings['challenge_court_numbers'],
        ));
    }

    public function isOpen(PlaySession $session): bool
    {
        $settings = $session->match_mode_settings ?? [];

        return (bool) ($settings['challenge_court_open'] ?? false);
    }

    /**
     * @param  list<int>  $courtNumbers
     */
    public function configureCourts(PlaySession $session, array $courtNumbers): void
    {
        $courtNumbers = array_values(array_unique(array_map('intval', $courtNumbers)));
        if (count($courtNumbers) > 2) {
            throw new \InvalidArgumentException('Select at most 2 challenge courts');
        }

        foreach ($courtNumbers as $number) {
            if ($number < 1 || $number > $session->court_count) {
                throw new \InvalidArgumentException("Court {$number} is not part of this session");
            }
        }

        $settings = $session->match_mode_settings ?? [];
        $settings['challenge_court_numbers'] = $courtNumbers;
        if ($courtNumbers === []) {
            $settings['challenge_court_open'] = false;
        } elseif (! array_key_exists('challenge_court_open', $settings)) {
            $settings['challenge_court_open'] = false;
        }

        $session->update(['match_mode_settings' => $settings]);

        Court::query()
            ->where('play_session_id', $session->id)
            ->update(['is_challenge_court' => false]);

        ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->update(['court_id' => null]);

        if ($courtNumbers !== []) {
            Court::query()
                ->where('play_session_id', $session->id)
                ->whereIn('court_number', $courtNumbers)
                ->update(['is_challenge_court' => true]);
        }
    }

    public function initializeForSession(PlaySession $session): void
    {
        $this->configureCourts($session, [1]);
    }

    public function open(PlaySession $session): void
    {
        if ($this->courtNumbers($session) === []) {
            throw new \RuntimeException('Select a challenge court before opening CC');
        }

        $settings = $session->match_mode_settings ?? [];
        $settings['challenge_court_open'] = true;
        $session->update(['match_mode_settings' => $settings]);
    }

    public function close(PlaySession $session): void
    {
        $settings = $session->match_mode_settings ?? [];
        $settings['challenge_court_open'] = false;
        $session->update(['match_mode_settings' => $settings]);
    }

    public function joinTeam(PlaySession $session, int $player1Id, int $player2Id): ChallengeCourtTeam
    {
        if (! $this->isOpen($session)) {
            throw new \RuntimeException('Challenge Court is not open');
        }

        return DB::transaction(function () use ($session, $player1Id, $player2Id) {
            $player1 = $this->requireEligiblePlayer($session, $player1Id);
            $player2 = $this->requireEligiblePlayer($session, $player2Id);

            if ($player1->id === $player2->id) {
                throw new \InvalidArgumentException('Select two different players');
            }

            if ($session->play_format === 'singles') {
                throw new \InvalidArgumentException('Challenge Court teams require doubles format');
            }

            $this->removeFromAllSessionQueues($session, $player1);
            $this->removeFromAllSessionQueues($session, $player2);

            $position = (int) (ChallengeCourtTeam::query()
                ->where('play_session_id', $session->id)
                ->max('position') ?? 0) + 1;

            return ChallengeCourtTeam::query()->create([
                'play_session_id' => $session->id,
                'player1_id' => $player1->id,
                'player2_id' => $player2->id,
                'position' => $position,
                'status' => ChallengeCourtTeam::STATUS_QUEUED,
                'cc_wins' => 0,
            ]);
        });
    }

    public function returnTeamToSession(PlaySession $session, int $teamId): void
    {
        DB::transaction(function () use ($session, $teamId) {
            $team = $this->requireTeam($session, $teamId);

            if ($team->status === ChallengeCourtTeam::STATUS_PLAYING) {
                throw new \RuntimeException('Cannot return a team while their match is active');
            }

            $players = $this->loadTeamPlayers($team);
            $this->routePlayersBackToSession($session, $players, $team);
            $team->delete();
            $this->reindexTeams($session);
        });
    }

    public function removeTeam(PlaySession $session, int $teamId): void
    {
        DB::transaction(function () use ($session, $teamId) {
            $team = $this->requireTeam($session, $teamId);

            if ($team->status === ChallengeCourtTeam::STATUS_PLAYING) {
                throw new \RuntimeException('Cannot remove a team while their match is active');
            }

            $team->delete();
            $this->reindexTeams($session);
        });
    }

    /**
     * @param  list<int>  $teamIds
     */
    public function reorderTeams(PlaySession $session, array $teamIds): void
    {
        $teams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->whereIn('status', [
                ChallengeCourtTeam::STATUS_QUEUED,
            ])
            ->get()
            ->keyBy('id');

        if (count($teamIds) !== $teams->count()) {
            throw new \InvalidArgumentException('Reorder must include every queued team');
        }

        foreach ($teamIds as $index => $teamId) {
            if (! $teams->has($teamId)) {
                throw new \InvalidArgumentException('Invalid team in reorder list');
            }
            $teams[$teamId]->update(['position' => $index + 1]);
        }
    }

    public function assignNextMatch(PlaySession $session, Court $court): bool
    {
        if (! $court->is_challenge_court) {
            throw new \InvalidArgumentException('This court is not a Challenge Court');
        }

        if (! $this->isOpen($session)) {
            throw new \RuntimeException('Challenge Court is not open');
        }

        if ($court->status !== 'available') {
            throw new \RuntimeException('Court is not available');
        }

        if ($this->defendingTeamOnCourt($session, $court) !== null) {
            throw new \RuntimeException(
                'A defending team is on this court. Use Next Challenger instead.',
            );
        }

        $queuedTeams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->orderBy('position')
            ->limit(2)
            ->get();

        if ($queuedTeams->count() < 2) {
            return false;
        }

        $teamA = $queuedTeams[0];
        $teamB = $queuedTeams[1];

        $this->startMatch($session, $court, $teamA, $teamB);

        return true;
    }

    public function assignNextChallenger(PlaySession $session, Court $court): bool
    {
        if (! $court->is_challenge_court) {
            throw new \InvalidArgumentException('This court is not a Challenge Court');
        }

        if (! $this->isOpen($session)) {
            throw new \RuntimeException('Challenge Court is not open');
        }

        if ($court->status !== 'available') {
            throw new \RuntimeException('Court is not available');
        }

        $defender = $this->defendingTeamOnCourt($session, $court);
        if ($defender === null || (int) $defender->cc_wins !== 1) {
            throw new \RuntimeException('Next Challenger is only available for a 1-0 defending team');
        }

        $challenger = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->orderBy('position')
            ->first();

        if ($challenger === null) {
            return false;
        }

        $this->startMatch($session, $court, $defender, $challenger);

        return true;
    }

    public function tryAutoAssign(PlaySession $session): void
    {
        if (! $session->auto_assign_enabled) {
            return;
        }

        if (! $this->isOpen($session)) {
            return;
        }

        $courts = Court::query()
            ->where('play_session_id', $session->id)
            ->where('is_challenge_court', true)
            ->where('status', 'available')
            ->orderBy('court_number')
            ->get();

        foreach ($courts as $court) {
            try {
                if ($this->defendingTeamOnCourt($session->fresh(), $court) !== null) {
                    continue;
                }

                if (! $this->assignNextMatch($session->fresh(), $court)) {
                    break;
                }
            } catch (\InvalidArgumentException|\RuntimeException) {
                break;
            }
        }
    }

    public function abortActiveMatch(PlaySession $session, MatchGame $match): void
    {
        if (! $match->is_challenge_court || $match->status !== 'in_match') {
            return;
        }

        $teams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('current_match_id', $match->id)
            ->get();

        foreach ($teams as $team) {
            $this->requeueTeam($session, $team);
        }

        $match->delete();
    }

    public function handleMatchFinished(PlaySession $session, MatchGame $match): void
    {
        if (! $match->is_challenge_court) {
            return;
        }

        $court = Court::query()->find($match->court_id);
        if ($court === null) {
            return;
        }

        $teams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('current_match_id', $match->id)
            ->get();

        if ($teams->count() !== 2) {
            return;
        }

        [$winner, $loser] = $this->resolveWinnerAndLoser($match, $teams);

        if ((int) $winner->cc_wins === 1 && (int) $loser->cc_wins === 0) {
            $this->requeueTeam($session, $winner);
            $this->requeueTeam($session, $loser);
            $this->fillVacantCourt($session, $court);

            return;
        }

        if ((int) $winner->cc_wins === 0 && (int) $loser->cc_wins === 1) {
            $this->requeueTeam($session, $loser);
            $winner->update([
                'status' => ChallengeCourtTeam::STATUS_IDLE,
                'cc_wins' => 1,
                'court_id' => $court->id,
                'current_match_id' => null,
            ]);

            return;
        }

        if ((int) $winner->cc_wins === 0 && (int) $loser->cc_wins === 0) {
            $winner->update([
                'status' => ChallengeCourtTeam::STATUS_IDLE,
                'cc_wins' => 1,
                'court_id' => $court->id,
                'current_match_id' => null,
            ]);
            $this->requeueTeam($session, $loser);
        }
    }

    public function isPlayerInChallengeCourt(PlaySession $session, int $playerId): bool
    {
        return ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where(function ($query) use ($playerId) {
                $query->where('player1_id', $playerId)
                    ->orWhere('player2_id', $playerId);
            })
            ->whereIn('status', [
                ChallengeCourtTeam::STATUS_QUEUED,
                ChallengeCourtTeam::STATUS_PLAYING,
                ChallengeCourtTeam::STATUS_IDLE,
            ])
            ->exists();
    }

    public function courtState(
        PlaySession $session,
        Court $court,
        ?ChallengeCourtSnapshot $snapshot = null,
    ): array {
        if (! $court->is_challenge_court) {
            return [];
        }

        $snapshot ??= ChallengeCourtSnapshot::load($session);

        $defender = $snapshot->defendingTeamOnCourt($court);
        $queuedCount = $snapshot->queuedTeamCount();
        $open = $this->isOpen($session);
        $available = $court->status === 'available';

        return [
            'defendingTeam' => $defender ? $this->formatTeam($defender) : null,
            'canAssignInitial' => $open
                && $available
                && $defender === null
                && $queuedCount >= 2,
            'canNextChallenger' => $open
                && $available
                && $defender !== null
                && (int) $defender->cc_wins === 1
                && $queuedCount >= 1,
        ];
    }

    public function buildState(PlaySession $session, ?ChallengeCourtSnapshot $snapshot = null): array
    {
        $snapshot ??= ChallengeCourtSnapshot::load($session);

        $teams = $snapshot->teams()
            ->map(fn (ChallengeCourtTeam $team) => $this->formatTeam($team));

        $eligible = $snapshot->eligiblePlayers();

        $hasAssignableCourt = Court::query()
            ->where('play_session_id', $session->id)
            ->where('is_challenge_court', true)
            ->where('status', 'available')
            ->get()
            ->contains(function (Court $court) use ($session, $snapshot) {
                $extras = $this->courtState($session, $court, $snapshot);

                return ($extras['canAssignInitial'] ?? false)
                    || ($extras['canNextChallenger'] ?? false);
            });

        return [
            'isOpen' => $this->isOpen($session),
            'courtNumbers' => $this->courtNumbers($session),
            'teams' => $teams->values()->all(),
            'eligiblePlayers' => $eligible,
            'canAssignNext' => $hasAssignableCourt,
        ];
    }

    private function defendingTeamOnCourt(PlaySession $session, Court $court): ?ChallengeCourtTeam
    {
        return ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('court_id', $court->id)
            ->where('status', ChallengeCourtTeam::STATUS_IDLE)
            ->with(['player1', 'player2'])
            ->first();
    }

    private function startMatch(
        PlaySession $session,
        Court $court,
        ChallengeCourtTeam $teamA,
        ChallengeCourtTeam $teamB,
    ): MatchGame {
        $match = $this->matchService->createChallengeCourtMatch($session, $court, $teamA, $teamB);

        $teamA->update([
            'status' => ChallengeCourtTeam::STATUS_PLAYING,
            'current_match_id' => $match->id,
            'court_id' => null,
        ]);
        $teamB->update([
            'status' => ChallengeCourtTeam::STATUS_PLAYING,
            'current_match_id' => $match->id,
            'court_id' => null,
        ]);

        return $match;
    }

    private function fillVacantCourt(PlaySession $session, Court $court): void
    {
        if ($court->status !== 'available') {
            return;
        }

        try {
            $this->assignNextMatch($session->fresh(), $court->fresh());
        } catch (\InvalidArgumentException|\RuntimeException) {
            // Court stays empty until more teams queue up.
        }
    }

    private function requeueTeam(PlaySession $session, ChallengeCourtTeam $team): void
    {
        $nextPosition = (int) (ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->max('position') ?? 0) + 1;

        $team->update([
            'status' => ChallengeCourtTeam::STATUS_QUEUED,
            'cc_wins' => 0,
            'court_id' => null,
            'current_match_id' => null,
            'position' => $nextPosition,
        ]);

        $this->reindexTeams($session);
    }

    /**
     * @param  Collection<int, ChallengeCourtTeam>  $teams
     * @return array{0: ChallengeCourtTeam, 1: ChallengeCourtTeam}
     */
    private function resolveWinnerAndLoser(MatchGame $match, Collection $teams): array
    {
        $teamA = $teams->first(fn (ChallengeCourtTeam $team) => $this->teamMatchesMatchSide($team, $match, 'a'));
        $teamB = $teams->first(fn (ChallengeCourtTeam $team) => $this->teamMatchesMatchSide($team, $match, 'b'));

        if ($teamA === null || $teamB === null) {
            throw new \RuntimeException('Could not resolve Challenge Court teams for this match');
        }

        $winner = $match->winner_team === 'A' ? $teamA : $teamB;
        $loser = $winner->id === $teamA->id ? $teamB : $teamA;

        return [$winner, $loser];
    }

    private function teamMatchesMatchSide(ChallengeCourtTeam $team, MatchGame $match, string $side): bool
    {
        $prefix = $side === 'a' ? 'team_a' : 'team_b';
        $matchPlayerIds = array_filter([
            $match->{$prefix.'_player1'},
            $match->{$prefix.'_player2'},
        ]);
        $teamPlayerIds = $team->playerIds();

        return count(array_intersect($matchPlayerIds, $teamPlayerIds)) === count($teamPlayerIds);
    }

    private function queuedTeamCount(PlaySession $session): int
    {
        return ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->count();
    }

    private function formatTeam(ChallengeCourtTeam $team): array
    {
        $names = array_filter([
            $team->player1?->name,
            $team->player2?->name,
        ]);

        return [
            'id' => $team->id,
            'displayName' => implode(' & ', $names),
            'player1' => $team->player1 ? [
                'id' => $team->player1->id,
                'name' => $team->player1->name,
            ] : null,
            'player2' => $team->player2 ? [
                'id' => $team->player2->id,
                'name' => $team->player2->name,
            ] : null,
            'position' => $team->position,
            'status' => $team->status,
            'ccWins' => (int) $team->cc_wins,
            'courtId' => $team->court_id,
            'currentMatchId' => $team->current_match_id,
        ];
    }

    private function requireTeam(PlaySession $session, int $teamId): ChallengeCourtTeam
    {
        $team = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('id', $teamId)
            ->first();

        if ($team === null) {
            throw new \InvalidArgumentException(
                'Challenge Court team not found. It may have already been removed.',
            );
        }

        return $team;
    }

    private function requireEligiblePlayer(PlaySession $session, int $playerId): Player
    {
        $player = Player::query()
            ->where('play_session_id', $session->id)
            ->where('id', $playerId)
            ->first();

        if (! $player || ! $player->is_active) {
            throw new \InvalidArgumentException('Player not found in this session');
        }

        if ($player->availability !== 'active') {
            throw new \InvalidArgumentException("{$player->name} is stepped out");
        }

        if ($this->isPlayerInChallengeCourt($session, $player->id)) {
            throw new \InvalidArgumentException("{$player->name} is already in Challenge Court");
        }

        if ($this->isPlayerOnActiveCourt($session, $player->id)) {
            throw new \InvalidArgumentException("{$player->name} is currently on a court");
        }

        return $player;
    }

    private function isPlayerOnActiveCourt(PlaySession $session, int $playerId): bool
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

    private function removeFromAllSessionQueues(PlaySession $session, Player $player): void
    {
        $this->queueService->removePlayer($session, $player);

        foreach (MatchMode::SKILL_LEVELS as $skill) {
            QueueEntry::query()
                ->where('play_session_id', $session->id)
                ->where('player_id', $player->id)
                ->where('queue_type', $skill)
                ->delete();
        }
    }

    /**
     * @return Collection<int, Player>
     */
    private function loadTeamPlayers(ChallengeCourtTeam $team): Collection
    {
        return collect([$team->player1, $team->player2])->filter();
    }

    /**
     * @param  Collection<int, Player>  $players
     */
    private function routePlayersBackToSession(
        PlaySession $session,
        Collection $players,
        ChallengeCourtTeam $team,
    ): void {
        $lastMatch = $this->lastFinishedMatchForTeam($session, $team);

        foreach ($players as $player) {
            $queueType = $this->resolveReturnQueue($session, $player, $lastMatch);
            $this->queueService->enqueueAtEnd($session, $player, $queueType);
        }
    }

    private function lastFinishedMatchForTeam(
        PlaySession $session,
        ChallengeCourtTeam $team,
    ): ?MatchGame {
        $playerIds = $team->playerIds();

        return MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('is_challenge_court', true)
            ->where('status', 'finished')
            ->where(function ($query) use ($playerIds) {
                foreach ($playerIds as $playerId) {
                    $query->orWhere(function ($q) use ($playerId) {
                        $q->where('team_a_player1', $playerId)
                            ->orWhere('team_a_player2', $playerId)
                            ->orWhere('team_b_player1', $playerId)
                            ->orWhere('team_b_player2', $playerId);
                    });
                }
            })
            ->orderByDesc('finished_at')
            ->first();
    }

    private function resolveReturnQueue(
        PlaySession $session,
        Player $player,
        ?MatchGame $lastMatch,
    ): string {
        if (MatchMode::usesSkillQueues($session->match_mode)) {
            return $player->skill_level ?? MatchMode::SKILL_LEVELS[0];
        }

        if ($lastMatch === null) {
            return 'loser';
        }

        $onTeamA = in_array($player->id, [
            $lastMatch->team_a_player1,
            $lastMatch->team_a_player2,
        ], true);

        $won = ($onTeamA && $lastMatch->winner_team === 'A')
            || (! $onTeamA && $lastMatch->winner_team === 'B');

        return $won ? 'winner' : 'loser';
    }

    private function reindexTeams(PlaySession $session): void
    {
        $teams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->orderBy('position')
            ->get();

        foreach ($teams as $index => $team) {
            $team->update(['position' => $index + 1]);
        }
    }
}
