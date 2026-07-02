<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PlaySession;
use App\Services\SessionExportService;
use App\Services\SessionHistoryService;
use App\Services\SessionService;
use App\Services\StateService;
use App\Support\BroadcastsSessionState;
use App\Support\MatchMode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(
        private SessionService $sessionService,
        private StateService $stateService,
        private SessionHistoryService $sessionHistoryService,
        private SessionExportService $sessionExportService,
    ) {}

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:120',
            'match_mode' => 'sometimes|string|in:'.implode(',', MatchMode::ALL),
            'play_format' => 'sometimes|in:doubles,singles',
            'court_count' => 'sometimes|integer|min:1|max:12',
            'auto_assign_enabled' => 'sometimes|boolean',
            'require_payment' => 'sometimes|boolean',
            'session_fee_cents' => 'sometimes|integer|min:0',
            'match_mode_settings' => 'sometimes|array',
        ]);

        $session = $this->sessionService->start($validated);

        return response()->json($this->broadcastState($session), 201);
    }

    public function active(): JsonResponse
    {
        $session = PlaySession::query()->where('status', 'active')->first();

        if (! $session) {
            return response()->json($this->stateService->buildActiveEmptyCached());
        }

        return response()->json(array_merge(
            ['active' => true],
            $this->stateService->buildActiveCached($session),
        ));
    }

    public function state(PlaySession $session): JsonResponse
    {
        return response()->json($this->stateService->buildCached($session));
    }

    public function live(PlaySession $session): JsonResponse
    {
        return response()->json($this->stateService->buildLiveCached($session));
    }

    public function end(PlaySession $session): JsonResponse
    {
        $report = $this->sessionService->end($session);
        $state = $this->broadcastState($session->fresh());

        return response()->json([
            'report' => $report,
            'state' => $state,
        ]);
    }

    public function updateSettings(Request $request, PlaySession $session): JsonResponse
    {
        $validated = $request->validate([
            'auto_assign_enabled' => 'sometimes|boolean',
            'require_payment' => 'sometimes|boolean',
            'session_fee_cents' => 'sometimes|integer|min:0',
            'court_count' => 'sometimes|integer|min:1|max:12',
        ]);

        try {
            $this->sessionService->updateSettings($session, $validated);
        } catch (\RuntimeException|\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function report(PlaySession $session): JsonResponse
    {
        if ($session->report_data) {
            return response()->json($session->report_data);
        }

        return response()->json($this->sessionService->buildReport($session));
    }

    public function calendar(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'year' => 'required|integer|min:2000|max:2100',
            'month' => 'required|integer|min:1|max:12',
        ]);

        return response()->json([
            'year' => $validated['year'],
            'month' => $validated['month'],
            // Empty PHP arrays JSON-encode as [] — Flutter expects a map.
            'markers' => (object) $this->sessionHistoryService->calendarMarkers(
                $validated['year'],
                $validated['month'],
            ),
        ]);
    }

    public function historyByDate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'date' => 'required|date_format:Y-m-d',
        ]);

        return response()->json([
            'date' => $validated['date'],
            'sessions' => $this->sessionHistoryService->sessionsOnDate($validated['date']),
        ]);
    }

    public function history(PlaySession $session): JsonResponse
    {
        return response()->json($this->sessionHistoryService->sessionDetail($session));
    }

    public function export(PlaySession $session): \Illuminate\Http\Response
    {
        $csv = $this->sessionExportService->toCsv($session);
        $filename = 'session-'.$session->id.'-report.csv';

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="'.$filename.'"',
        ]);
    }
}
