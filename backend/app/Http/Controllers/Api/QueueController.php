<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PlaySession;
use App\Models\Player;
use App\Services\SessionService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class QueueController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(private SessionService $sessionService) {}

    public function move(Request $request, PlaySession $session): JsonResponse
    {
        $validated = $request->validate([
            'player_id' => 'required|integer',
            'queue_type' => 'required|string',
            'position' => 'required|integer|min:1',
        ]);

        $player = Player::query()
            ->where('play_session_id', $session->id)
            ->findOrFail($validated['player_id']);

        try {
            $this->sessionService->moveQueuePlayer(
                $session,
                $player,
                $validated['queue_type'],
                $validated['position'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }
}
