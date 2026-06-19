<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PlaySession;
use App\Services\LeaderboardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LeaderboardController extends Controller
{
    public function __construct(private LeaderboardService $leaderboardService) {}

    public function allTime(): JsonResponse
    {
        return response()->json([
            'scope' => 'all_time',
            'leaderboard' => $this->leaderboardService->allTime(),
        ]);
    }

    public function session(PlaySession $session): JsonResponse
    {
        return response()->json([
            'scope' => 'session',
            'sessionId' => $session->id,
            'sessionName' => $session->name,
            'leaderboard' => $this->leaderboardService->session($session),
        ]);
    }

    public function monthly(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'year' => 'sometimes|integer|min:2000|max:2100',
            'month' => 'sometimes|integer|min:1|max:12',
        ]);

        $year = $validated['year'] ?? now()->year;
        $month = $validated['month'] ?? now()->month;
        $result = $this->leaderboardService->monthly($year, $month);

        return response()->json([
            'scope' => 'monthly',
            'year' => $year,
            'month' => $month,
            'label' => date('F Y', mktime(0, 0, 0, $month, 1, $year)),
            'leaderboard' => $result['leaderboard'],
        ]);
    }

    public function season(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'year' => 'sometimes|integer|min:2000|max:2100',
        ]);

        $year = $validated['year'] ?? now()->year;
        $result = $this->leaderboardService->season($year);

        return response()->json([
            'scope' => 'season',
            'year' => (int) $year,
            'label' => "Season {$year}",
            'leaderboard' => $result['leaderboard'],
        ]);
    }
}
