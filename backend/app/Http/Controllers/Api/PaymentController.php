<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ClubPlayer;
use App\Models\PlaySession;
use App\Services\PaymentService;
use App\Services\RevenueService;
use App\Services\SessionService;
use App\Services\StateService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(
        private PaymentService $paymentService,
        private SessionService $sessionService,
        private StateService $stateService,
        private RevenueService $revenueService,
    ) {}

    public function markPaid(Request $request, PlaySession $session, ClubPlayer $clubPlayer): JsonResponse
    {
        $validated = $request->validate([
            'method' => 'sometimes|in:cash,transfer,other',
            'amount_cents' => 'sometimes|integer|min:0',
        ]);

        try {
            $sessionPlayer = $this->paymentService->markPaid(
                $session,
                $clubPlayer,
                $validated['method'] ?? 'cash',
                $validated['amount_cents'] ?? null,
            );
            $player = $this->sessionService->tryActivateAfterPayment($session, $clubPlayer);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $state = $this->broadcastState($session->fresh());

        return response()->json([
            'registration' => [
                'clubPlayerId' => $clubPlayer->id,
                'paymentStatus' => $sessionPlayer->payment_status,
            ],
            'player' => $player ? [
                'id' => $player->id,
                'name' => $player->name,
                'clubPlayerId' => $clubPlayer->id,
            ] : null,
            'state' => $state,
        ]);
    }

    public function markWaived(Request $request, PlaySession $session, ClubPlayer $clubPlayer): JsonResponse
    {
        $validated = $request->validate([
            'notes' => 'sometimes|string|max:255',
        ]);

        try {
            $sessionPlayer = $this->paymentService->markWaived(
                $session,
                $clubPlayer,
                $validated['notes'] ?? null,
            );
            $player = $this->sessionService->tryActivateAfterPayment($session, $clubPlayer);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $state = $this->broadcastState($session->fresh());

        return response()->json([
            'registration' => [
                'clubPlayerId' => $clubPlayer->id,
                'paymentStatus' => $sessionPlayer->payment_status,
            ],
            'player' => $player ? [
                'id' => $player->id,
                'name' => $player->name,
                'clubPlayerId' => $clubPlayer->id,
            ] : null,
            'state' => $state,
        ]);
    }

    public function activate(Request $request, PlaySession $session, ClubPlayer $clubPlayer): JsonResponse
    {
        try {
            $player = $this->sessionService->activateClubPlayerInSession($session, $clubPlayer);
        } catch (\App\Exceptions\PaymentRequiredException $e) {
            return response()->json(['message' => $e->getMessage()], 402);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $state = $this->broadcastState($session->fresh());

        return response()->json([
            'player' => [
                'id' => $player->id,
                'name' => $player->name,
                'clubPlayerId' => $clubPlayer->id,
            ],
            'state' => $state,
        ], 201);
    }

    public function revenue(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'from' => 'sometimes|date_format:Y-m-d',
            'to' => 'sometimes|date_format:Y-m-d',
            'session_id' => 'sometimes|integer|exists:play_sessions,id',
        ]);

        return response()->json($this->revenueService->summary(
            $validated['from'] ?? null,
            $validated['to'] ?? null,
            isset($validated['session_id']) ? (int) $validated['session_id'] : null,
        ));
    }

    public function exportRevenue(Request $request): \Illuminate\Http\Response
    {
        $validated = $request->validate([
            'from' => 'sometimes|date_format:Y-m-d',
            'to' => 'sometimes|date_format:Y-m-d',
            'session_id' => 'sometimes|integer|exists:play_sessions,id',
        ]);

        $csv = $this->revenueService->toCsv(
            $validated['from'] ?? null,
            $validated['to'] ?? null,
            isset($validated['session_id']) ? (int) $validated['session_id'] : null,
        );

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="revenue-export.csv"',
        ]);
    }
}
