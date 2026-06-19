<?php

namespace App\Services;

use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use App\Support\MatchMode;
use Carbon\Carbon;

class SessionHistoryService
{
    public function __construct(
        private SessionService $sessionService,
        private MatchService $matchService,
    ) {}

    /**
     * @return array<string, int>
     */
    public function calendarMarkers(int $year, int $month): array
    {
        $start = Carbon::create($year, $month, 1)->startOfMonth();
        $end = $start->copy()->endOfMonth();

        $sessions = PlaySession::query()
            ->where(function ($query) use ($start, $end) {
                $query->whereBetween('started_at', [$start, $end])
                    ->orWhereBetween('ended_at', [$start, $end])
                    ->orWhere(function ($nested) use ($start, $end) {
                        $nested->whereNull('started_at')
                            ->whereBetween('created_at', [$start, $end]);
                    });
            })
            ->get();

        $markers = [];
        foreach ($sessions as $session) {
            $date = $this->sessionCalendarDate($session);
            if ($date->between($start, $end)) {
                $key = $date->format('Y-m-d');
                $markers[$key] = ($markers[$key] ?? 0) + 1;
            }
        }

        ksort($markers);

        return $markers;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function sessionsOnDate(string $date): array
    {
        $day = Carbon::parse($date)->startOfDay();
        $dayEnd = $day->copy()->endOfDay();

        return PlaySession::query()
            ->where(function ($query) use ($day, $dayEnd) {
                $query->whereBetween('started_at', [$day, $dayEnd])
                    ->orWhereBetween('ended_at', [$day, $dayEnd])
                    ->orWhere(function ($nested) use ($day, $dayEnd) {
                        $nested->whereNull('started_at')
                            ->whereBetween('created_at', [$day, $dayEnd]);
                    });
            })
            ->orderByDesc('started_at')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (PlaySession $session) => $this->formatSessionSummary($session))
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    public function sessionDetail(PlaySession $session): array
    {
        $report = $session->report_data ?? $this->sessionService->buildReport($session);

        $matches = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->with(['teamAPlayer1', 'teamAPlayer2', 'teamBPlayer1', 'teamBPlayer2', 'court'])
            ->orderBy('finished_at')
            ->orderBy('started_at')
            ->get()
            ->map(fn (MatchGame $match) => array_merge(
                $this->matchService->formatMatch($match),
                [
                    'courtNumber' => $match->court?->court_number,
                    'teamALabel' => $this->teamLabel($match, 'A'),
                    'teamBLabel' => $this->teamLabel($match, 'B'),
                ]
            ))
            ->values()
            ->all();

        $players = Player::query()
            ->where('play_session_id', $session->id)
            ->orderBy('name')
            ->get()
            ->map(fn (Player $player) => [
                'id' => $player->id,
                'name' => $player->name,
                'wins' => $player->wins,
                'losses' => $player->losses,
                'skillLevel' => $player->skill_level,
                'gender' => $player->gender,
            ])
            ->values()
            ->all();

        return [
            'session' => $this->formatSessionSummary($session),
            'report' => $report,
            'matches' => $matches,
            'players' => $players,
        ];
    }

    private function sessionCalendarDate(PlaySession $session): Carbon
    {
        $timestamp = $session->ended_at
            ?? $session->started_at
            ?? $session->created_at;

        return Carbon::parse($timestamp)->startOfDay();
    }

    /**
     * @return array<string, mixed>
     */
    private function formatSessionSummary(PlaySession $session): array
    {
        $startedAt = $session->started_at ?? $session->created_at;
        $matchCount = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'finished')
            ->count();

        return [
            'id' => $session->id,
            'name' => $session->name,
            'status' => $session->status,
            'matchMode' => $session->match_mode,
            'matchModeLabel' => MatchMode::label($session->match_mode ?? MatchMode::AUTO_BALANCED),
            'playFormat' => $session->play_format,
            'courtCount' => $session->court_count,
            'totalMatches' => $matchCount,
            'playerCount' => $session->players()->count(),
            'startedAt' => $startedAt?->toIso8601String(),
            'endedAt' => $session->ended_at?->toIso8601String(),
            'calendarDate' => $this->sessionCalendarDate($session)->format('Y-m-d'),
        ];
    }

    private function teamLabel(MatchGame $match, string $team): string
    {
        $players = $team === 'A'
            ? collect([$match->teamAPlayer1, $match->teamAPlayer2])->filter()
            : collect([$match->teamBPlayer1, $match->teamBPlayer2])->filter();

        return $players->pluck('name')->join(' & ');
    }
}
