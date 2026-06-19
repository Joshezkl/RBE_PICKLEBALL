<?php

namespace App\Services;

use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;

class SessionExportService
{
    public function __construct(
        private SessionHistoryService $historyService,
        private LeaderboardService $leaderboardService,
        private RevenueService $revenueService,
    ) {}

    public function toCsv(PlaySession $session): string
    {
        $detail = $this->historyService->sessionDetail($session);
        $leaderboard = $this->leaderboardService->session($session);

        $lines = [];
        $lines[] = $this->csvRow(['Rosales Pickleball Club — Session Report']);
        $lines[] = $this->csvRow(['Session', $detail['session']['name'] ?? $session->name]);
        $lines[] = $this->csvRow(['Mode', $detail['session']['matchModeLabel'] ?? '']);
        $lines[] = $this->csvRow(['Status', $detail['session']['status'] ?? '']);
        $lines[] = $this->csvRow(['Total Matches', $detail['report']['totalMatches'] ?? 0]);
        $lines[] = $this->csvRow(['Duration (min)', $detail['report']['durationMinutes'] ?? 0]);
        $lines[] = $this->csvRow(['Court Utilization %', $detail['report']['courtUtilizationPercent'] ?? 0]);
        $lines[] = $this->csvRow(['Avg Match Duration (min)', $detail['report']['avgMatchDurationMinutes'] ?? 0]);
        $lines[] = '';

        $lines[] = $this->csvRow(['Roster']);
        $lines[] = $this->csvRow(['Name', 'Wins', 'Losses', 'Skill', 'Gender']);
        foreach ($detail['players'] as $player) {
            $lines[] = $this->csvRow([
                $player['name'],
                $player['wins'],
                $player['losses'],
                $player['skillLevel'] ?? '',
                $player['gender'] ?? '',
            ]);
        }
        $lines[] = '';

        $lines[] = $this->csvRow(['Match Results']);
        $lines[] = $this->csvRow([
            'Court', 'Team A', 'Team B', 'Score A', 'Score B', 'Winner', 'Finished At',
        ]);
        foreach ($detail['matches'] as $match) {
            if (($match['status'] ?? '') !== 'finished') {
                continue;
            }
            $lines[] = $this->csvRow([
                $match['courtNumber'] ?? '',
                $match['teamALabel'] ?? '',
                $match['teamBLabel'] ?? '',
                $match['scoreA'] ?? '',
                $match['scoreB'] ?? '',
                $match['winnerTeam'] ?? '',
                $match['finishedAt'] ?? '',
            ]);
        }
        $lines[] = '';

        $lines[] = $this->csvRow(['Session Leaderboard (min 3 matches)']);
        $lines[] = $this->csvRow([
            'Rank', 'Name', 'Win Rate', 'Wins', 'Losses', 'Matches', 'PD', 'Avg Margin',
        ]);
        foreach ($leaderboard as $entry) {
            $lines[] = $this->csvRow([
                $entry['rank'],
                $entry['name'],
                $entry['winRate'],
                $entry['wins'],
                $entry['losses'],
                $entry['matches'],
                $entry['pointDifferential'] ?? 0,
                $entry['avgMargin'] ?? 0,
            ]);
        }

        $lines = array_merge($lines, $this->revenueService->sessionReportLines($session));

        return implode("\n", $lines)."\n";
    }

    /**
     * @param  list<mixed>  $fields
     */
    private function csvRow(array $fields): string
    {
        return implode(',', array_map(function ($value) {
            $text = (string) $value;
            if (str_contains($text, ',') || str_contains($text, '"') || str_contains($text, "\n")) {
                return '"'.str_replace('"', '""', $text).'"';
            }

            return $text;
        }, $fields));
    }
}
