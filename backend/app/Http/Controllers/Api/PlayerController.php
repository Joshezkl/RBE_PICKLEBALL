<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\PaymentRequiredException;
use App\Http\Controllers\Controller;
use App\Models\PlaySession;
use App\Models\Player;
use App\Services\SessionService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PlayerController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(private SessionService $sessionService) {}

    public function store(Request $request, PlaySession $session): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'skill_level' => 'sometimes|in:beginner,novice,intermediate,advanced',
            'gender' => 'sometimes|in:male,female,other',
            'payment_action' => 'sometimes|in:pending,paid,waived',
        ]);

        try {
            $player = $this->sessionService->addPlayer(
                $session,
                $validated['name'],
                $validated['skill_level'] ?? null,
                $validated['gender'] ?? null,
                $validated['payment_action'] ?? null,
            );
        } catch (PaymentRequiredException $e) {
            $state = $this->broadcastState($session->fresh());

            return response()->json([
                'message' => $e->getMessage(),
                'pending' => true,
                'state' => $state,
            ], 202);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $state = $this->broadcastState($session->fresh());

        return response()->json([
            'player' => [
                'id' => $player->id,
                'name' => $player->name,
            ],
            'state' => $state,
        ], 201);
    }

    public function update(Request $request, PlaySession $session, Player $player): JsonResponse
    {
        if ($player->play_session_id !== $session->id) {
            return response()->json(['message' => 'Player not in this session'], 404);
        }

        $validated = $request->validate([
            'name' => 'required|string|max:100',
        ]);

        try {
            $player = $this->sessionService->updatePlayerName(
                $session,
                $player,
                $validated['name'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $state = $this->broadcastState($session->fresh());

        return response()->json([
            'player' => [
                'id' => $player->id,
                'name' => $player->name,
            ],
            'state' => $state,
        ]);
    }

    public function destroy(PlaySession $session, Player $player): JsonResponse
    {
        if ($player->play_session_id !== $session->id) {
            return response()->json(['message' => 'Player not in this session'], 404);
        }

        try {
            $this->sessionService->removePlayer($session, $player);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }
}
