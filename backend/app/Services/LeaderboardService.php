<?php

namespace App\Services;

use App\Models\ClubPlayer;
use App\Models\PlaySession;
use App\Models\SessionPlayer;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class LeaderboardService
{
    private const MIN_MATCHES = 3;

    public function allTime(): array
    {
        $players = ClubPlayer::query()
            ->where('is_guest', false)
            ->where('is_tournament_only', false)
            ->where('total_matches', '>=', self::MIN_MATCHES)
            ->get();

        return $this->rankClubPlayers($players);
    }

    public function session(PlaySession $session): array
    {
        $entries = SessionPlayer::query()
            ->with('clubPlayer')
            ->where('play_session_id', $session->id)
            ->whereHas('clubPlayer', fn ($q) => $q->where('is_guest', false))
            ->where('session_matches', '>=', self::MIN_MATCHES)
            ->get();

        return $this->rankSessionPlayers($entries);
    }

    public function monthly(?int $year = null, ?int $month = null): array
    {
        $now = now();
        $year = $year ?? $now->year;
        $month = $month ?? $now->month;

        return $this->period(
            Carbon::create($year, $month, 1)->startOfMonth(),
            Carbon::create($year, $month, 1)->endOfMonth(),
            "month:{$year}-{$month}",
        );
    }

    public function season(?int $year = null): array
    {
        $year = $year ?? now()->year;

        return $this->period(
            Carbon::create($year, 1, 1)->startOfDay(),
            Carbon::create($year, 12, 31)->endOfDay(),
            "season:{$year}",
        );
    }

    /**
     * @return array{leaderboard: list<array<string, mixed>>, label: string}
     */
    private function period(Carbon $start, Carbon $end, string $labelKey): array
    {
        $sessionIds = PlaySession::query()
            ->where(function ($query) use ($start, $end) {
                $query->whereBetween('started_at', [$start, $end])
                    ->orWhereBetween('ended_at', [$start, $end]);
            })
            ->pluck('id');

        $entries = SessionPlayer::query()
            ->with('clubPlayer')
            ->whereIn('play_session_id', $sessionIds)
            ->whereHas('clubPlayer', fn ($q) => $q->where('is_guest', false))
            ->get()
            ->groupBy('club_player_id')
            ->map(function (Collection $group) {
                /** @var SessionPlayer $first */
                $first = $group->first();
                $club = $first->clubPlayer;

                $matches = $group->sum('session_matches');
                $wins = $group->sum('session_wins');
                $losses = $group->sum('session_losses');
                $scored = $group->sum('session_points_scored');
                $allowed = $group->sum('session_points_allowed');
                $pd = $scored - $allowed;

                return [
                    'name' => $club->publicName(),
                    'gender' => $club->gender,
                    'skillLevel' => $club->skill_level,
                    'wins' => $wins,
                    'losses' => $losses,
                    'matches' => $matches,
                    'winRate' => $matches > 0 ? round(($wins / $matches) * 100, 1) : 0.0,
                    'pointsScored' => $scored,
                    'pointsAllowed' => $allowed,
                    'pointDifferential' => $pd,
                    'avgMargin' => $matches > 0 ? round($pd / $matches, 1) : 0.0,
                ];
            })
            ->filter(fn (array $row) => $row['matches'] >= self::MIN_MATCHES)
            ->values();

        return [
            'label' => $labelKey,
            'leaderboard' => $this->rankRows($entries),
        ];
    }

    /**
     * @param  Collection<int, ClubPlayer>  $players
     */
    private function rankClubPlayers(Collection $players): array
    {
        $rows = $players->map(fn (ClubPlayer $p) => [
            'name' => $p->publicName(),
            'gender' => $p->gender,
            'skillLevel' => $p->skill_level,
            'wins' => $p->total_wins,
            'losses' => $p->total_losses,
            'matches' => $p->total_matches,
            'winRate' => $p->winRate(),
            'pointsScored' => $p->total_points_scored,
            'pointsAllowed' => $p->total_points_allowed,
            'pointDifferential' => $p->pointDifferential(),
            'avgMargin' => $p->avgMargin(),
        ]);

        return $this->rankRows($rows);
    }

    /**
     * @param  Collection<int, SessionPlayer>  $entries
     */
    private function rankSessionPlayers(Collection $entries): array
    {
        $rows = $entries->map(fn (SessionPlayer $e) => [
            'name' => $e->clubPlayer->publicName(),
            'gender' => $e->clubPlayer->gender,
            'skillLevel' => $e->clubPlayer->skill_level,
            'wins' => $e->session_wins,
            'losses' => $e->session_losses,
            'matches' => $e->session_matches,
            'winRate' => $e->sessionWinRate(),
            'pointsScored' => $e->session_points_scored,
            'pointsAllowed' => $e->session_points_allowed,
            'pointDifferential' => $e->sessionPointDifferential(),
            'avgMargin' => $e->sessionAvgMargin(),
        ]);

        return $this->rankRows($rows);
    }

    /**
     * @param  Collection<int, array<string, mixed>>  $rows
     */
    private function rankRows(Collection $rows): array
    {
        $sorted = $rows
            ->sort(function (array $a, array $b) {
                $rateCmp = ($b['winRate'] ?? 0) <=> ($a['winRate'] ?? 0);
                if ($rateCmp !== 0) {
                    return $rateCmp;
                }

                $pdCmp = ($b['pointDifferential'] ?? 0) <=> ($a['pointDifferential'] ?? 0);
                if ($pdCmp !== 0) {
                    return $pdCmp;
                }

                return ($b['wins'] ?? 0) <=> ($a['wins'] ?? 0);
            })
            ->values();

        $ranked = [];
        $rank = 1;

        foreach ($sorted as $row) {
            $ranked[] = array_merge(['rank' => $rank], $row);
            $rank++;
        }

        return $ranked;
    }
}
