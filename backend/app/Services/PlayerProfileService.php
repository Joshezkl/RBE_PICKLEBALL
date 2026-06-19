<?php

namespace App\Services;

use App\Models\ClubPlayer;
use App\Models\MatchGame;
use App\Models\Player;
use App\Models\SessionPlayer;
use App\Support\MatchMode;

class PlayerProfileService
{
    public function __construct(private ClubPlayerService $clubPlayerService) {}

    /**
     * @return array<string, mixed>
     */
    public function build(ClubPlayer $clubPlayer): array
    {
        $base = $this->clubPlayerService->formatClubPlayer($clubPlayer);

        $sessionPlayers = SessionPlayer::query()
            ->with('playSession')
            ->where('club_player_id', $clubPlayer->id)
            ->where('session_matches', '>', 0)
            ->get()
            ->sortByDesc(fn (SessionPlayer $sp) => $sp->playSession?->started_at ?? $sp->created_at)
            ->values();

        $sessionHistory = $sessionPlayers->map(fn (SessionPlayer $sp) => [
            'sessionId' => $sp->play_session_id,
            'sessionName' => $sp->playSession?->name ?? 'Session',
            'matchMode' => $sp->playSession?->match_mode,
            'matchModeLabel' => MatchMode::label($sp->playSession?->match_mode ?? 'auto_balanced'),
            'startedAt' => $sp->playSession?->started_at?->toIso8601String(),
            'wins' => $sp->session_wins,
            'losses' => $sp->session_losses,
            'matches' => $sp->session_matches,
            'winRate' => $sp->sessionWinRate(),
            'pointDifferential' => $sp->sessionPointDifferential(),
            'avgMargin' => $sp->sessionAvgMargin(),
        ])->values()->all();

        $preferredMode = $sessionPlayers
            ->groupBy(fn (SessionPlayer $sp) => $sp->playSession?->match_mode ?? 'unknown')
            ->sortByDesc(fn ($group) => $group->sum('session_matches'))
            ->keys()
            ->first();

        $winRateTrend = $sessionPlayers
            ->sortBy(fn (SessionPlayer $sp) => $sp->playSession?->started_at ?? $sp->created_at)
            ->take(-12)
            ->map(fn (SessionPlayer $sp) => [
                'label' => $sp->playSession?->name ?? 'Session',
                'date' => $sp->playSession?->started_at?->format('Y-m-d'),
                'winRate' => $sp->sessionWinRate(),
                'matches' => $sp->session_matches,
            ])
            ->values()
            ->all();

        return array_merge($base, [
            'sessionHistory' => $sessionHistory,
            'preferredMode' => $preferredMode,
            'preferredModeLabel' => $preferredMode
                ? MatchMode::label($preferredMode)
                : null,
            'bestPartners' => $this->bestPartners($clubPlayer),
            'winRateTrend' => $winRateTrend,
        ]);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function bestPartners(ClubPlayer $clubPlayer): array
    {
        $rosterIds = Player::query()
            ->where('club_player_id', $clubPlayer->id)
            ->pluck('id');

        if ($rosterIds->isEmpty()) {
            return [];
        }

        $matches = MatchGame::query()
            ->where('status', 'finished')
            ->where(function ($q) use ($rosterIds) {
                $q->whereIn('team_a_player1', $rosterIds)
                    ->orWhereIn('team_a_player2', $rosterIds)
                    ->orWhereIn('team_b_player1', $rosterIds)
                    ->orWhereIn('team_b_player2', $rosterIds);
            })
            ->with([
                'teamAPlayer1.clubPlayer',
                'teamAPlayer2.clubPlayer',
                'teamBPlayer1.clubPlayer',
                'teamBPlayer2.clubPlayer',
            ])
            ->get();

        $partnerStats = [];

        foreach ($matches as $match) {
            $rosterOnA = $this->rosterOnTeam($match, 'A', $rosterIds);
            $rosterOnB = $this->rosterOnTeam($match, 'B', $rosterIds);

            if ($rosterOnA->isNotEmpty()) {
                $this->tallyPartners($partnerStats, $rosterOnA, $match, 'A');
            }
            if ($rosterOnB->isNotEmpty()) {
                $this->tallyPartners($partnerStats, $rosterOnB, $match, 'B');
            }
        }

        return collect($partnerStats)
            ->sortByDesc('matchesTogether')
            ->take(5)
            ->values()
            ->all();
    }

    /**
     * @param  \Illuminate\Support\Collection<int, int>  $rosterIds
     * @return \Illuminate\Support\Collection<int, int>
     */
    private function rosterOnTeam(MatchGame $match, string $team, $rosterIds)
    {
        $ids = collect();
        if ($team === 'A') {
            if ($match->team_a_player1 && $rosterIds->contains($match->team_a_player1)) {
                $ids->push($match->team_a_player1);
            }
            if ($match->team_a_player2 && $rosterIds->contains($match->team_a_player2)) {
                $ids->push($match->team_a_player2);
            }

            return $ids;
        }

        if ($match->team_b_player1 && $rosterIds->contains($match->team_b_player1)) {
            $ids->push($match->team_b_player1);
        }
        if ($match->team_b_player2 && $rosterIds->contains($match->team_b_player2)) {
            $ids->push($match->team_b_player2);
        }

        return $ids;
    }

    /**
     * @param  array<string, array<string, mixed>>  $partnerStats
     * @param  \Illuminate\Support\Collection<int, int>  $rosterOnTeam
     */
    private function tallyPartners(
        array &$partnerStats,
        $rosterOnTeam,
        MatchGame $match,
        string $team,
    ): void {
        $teammates = $this->teamPlayers($match, $team)
            ->filter(fn (?Player $p) => $p && ! $rosterOnTeam->contains($p->id));

        $won = $match->winner_team === $team;

        foreach ($teammates as $partner) {
            $key = $partner->club_player_id
                ? 'club:'.$partner->club_player_id
                : 'name:'.$partner->name;

            if (! isset($partnerStats[$key])) {
                $partnerStats[$key] = [
                    'name' => $partner->clubPlayer?->publicName() ?? $partner->name,
                    'matchesTogether' => 0,
                    'winsTogether' => 0,
                ];
            }

            $partnerStats[$key]['matchesTogether']++;
            if ($won) {
                $partnerStats[$key]['winsTogether']++;
            }
        }
    }

    /**
     * @return \Illuminate\Support\Collection<int, Player>
     */
    private function teamPlayers(MatchGame $match, string $team)
    {
        if ($team === 'A') {
            return collect([
                $match->teamAPlayer1,
                $match->teamAPlayer2,
            ])->filter();
        }

        return collect([
            $match->teamBPlayer1,
            $match->teamBPlayer2,
        ])->filter();
    }
}
