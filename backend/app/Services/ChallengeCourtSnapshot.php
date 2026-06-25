<?php

namespace App\Services;

use App\Models\ChallengeCourtTeam;
use App\Models\Court;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use Illuminate\Support\Collection;

/**
 * Preloaded Challenge Court data for session state — avoids per-player exists() queries.
 */
final class ChallengeCourtSnapshot
{
    /** @var array<int, true> */
    private array $challengeCourtPlayerIds;

    /** @var array<int, true> */
    private array $activeCourtPlayerIds;

    /** @var Collection<int, ChallengeCourtTeam> */
    private Collection $defendersByCourtId;

    /**
     * @param  Collection<int, ChallengeCourtTeam>  $teams
     */
    public function __construct(
        private PlaySession $session,
        private Collection $teams,
        array $challengeCourtPlayerIds,
        array $activeCourtPlayerIds,
    ) {
        $this->challengeCourtPlayerIds = array_fill_keys($challengeCourtPlayerIds, true);
        $this->activeCourtPlayerIds = array_fill_keys($activeCourtPlayerIds, true);

        $this->defendersByCourtId = $teams
            ->filter(
                fn (ChallengeCourtTeam $team) => $team->status === ChallengeCourtTeam::STATUS_IDLE
                    && $team->court_id !== null,
            )
            ->keyBy('court_id');
    }

    public static function load(PlaySession $session): self
    {
        $teams = ChallengeCourtTeam::query()
            ->where('play_session_id', $session->id)
            ->with(['player1', 'player2'])
            ->orderBy('position')
            ->get();

        $activeStatuses = [
            ChallengeCourtTeam::STATUS_QUEUED,
            ChallengeCourtTeam::STATUS_PLAYING,
            ChallengeCourtTeam::STATUS_IDLE,
        ];

        $challengeCourtPlayerIds = $teams
            ->filter(fn (ChallengeCourtTeam $team) => in_array($team->status, $activeStatuses, true))
            ->flatMap(fn (ChallengeCourtTeam $team) => $team->playerIds())
            ->unique()
            ->values()
            ->all();

        $activeCourtPlayerIds = self::loadActiveCourtPlayerIds($session);

        return new self($session, $teams, $challengeCourtPlayerIds, $activeCourtPlayerIds);
    }

    public function session(): PlaySession
    {
        return $this->session;
    }

    /**
     * @return Collection<int, ChallengeCourtTeam>
     */
    public function teams(): Collection
    {
        return $this->teams;
    }

    public function queuedTeamCount(): int
    {
        return $this->teams
            ->where('status', ChallengeCourtTeam::STATUS_QUEUED)
            ->count();
    }

    public function isPlayerInChallengeCourt(int $playerId): bool
    {
        return isset($this->challengeCourtPlayerIds[$playerId]);
    }

    public function isPlayerOnActiveCourt(int $playerId): bool
    {
        return isset($this->activeCourtPlayerIds[$playerId]);
    }

    public function defendingTeamOnCourt(Court $court): ?ChallengeCourtTeam
    {
        return $this->defendersByCourtId->get($court->id);
    }

    /**
     * @return list<int>
     */
    private static function loadActiveCourtPlayerIds(PlaySession $session): array
    {
        $matchIds = Court::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->whereNotNull('current_match_id')
            ->pluck('current_match_id');

        if ($matchIds->isEmpty()) {
            return [];
        }

        return MatchGame::query()
            ->whereIn('id', $matchIds)
            ->where('status', 'in_match')
            ->get()
            ->flatMap(fn (MatchGame $match) => array_filter([
                $match->team_a_player1,
                $match->team_a_player2,
                $match->team_b_player1,
                $match->team_b_player2,
            ]))
            ->unique()
            ->values()
            ->all();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function eligiblePlayers(): array
    {
        return Player::query()
            ->where('play_session_id', $this->session->id)
            ->where('is_active', true)
            ->where('availability', 'active')
            ->orderBy('name')
            ->get()
            ->reject(fn (Player $player) => $this->isPlayerInChallengeCourt($player->id))
            ->reject(fn (Player $player) => $this->isPlayerOnActiveCourt($player->id))
            ->map(fn (Player $player) => [
                'id' => $player->id,
                'name' => $player->name,
                'wins' => $player->wins,
                'losses' => $player->losses,
            ])
            ->values()
            ->all();
    }
}
