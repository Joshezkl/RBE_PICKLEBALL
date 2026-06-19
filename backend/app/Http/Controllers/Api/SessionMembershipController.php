<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\PaymentRequiredException;
use App\Http\Controllers\Controller;
use App\Models\ClubPlayer;
use App\Models\PlaySession;
use App\Models\Player;
use App\Services\SessionService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionMembershipController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(private SessionService $sessionService) {}

    public function join(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'club_player_id' => 'required|exists:club_players,id',
            'payment_action' => 'sometimes|in:pending,paid,waived',
        ]);

        $session = PlaySession::query()->where('status', 'active')->first();
        if (! $session) {
            return response()->json(['message' => 'No active session'], 404);
        }

        $clubPlayer = ClubPlayer::query()->findOrFail($validated['club_player_id']);

        $alreadyInSession = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayer->id)
            ->exists();

        if ($alreadyInSession) {
            return response()->json(['message' => 'Player is already in this session'], 422);
        }

        try {
            $player = $this->sessionService->addClubPlayerToSession(
                $session,
                $clubPlayer,
                paymentAction: $validated['payment_action'] ?? null,
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
                'clubPlayerId' => $clubPlayer->id,
            ],
            'state' => $state,
        ], 201);
    }

    public function remove(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'club_player_id' => 'required_without:player_id|exists:club_players,id',
            'player_id' => 'required_without:club_player_id|exists:players,id',
        ]);

        $session = PlaySession::query()->where('status', 'active')->first();
        if (! $session) {
            return response()->json(['message' => 'No active session'], 404);
        }

        if (isset($validated['player_id'])) {
            $player = Player::query()->findOrFail($validated['player_id']);
        } else {
            $player = Player::query()
                ->where('play_session_id', $session->id)
                ->where('club_player_id', $validated['club_player_id'])
                ->first();

            if (! $player) {
                return response()->json(['message' => 'Player is not in this session'], 404);
            }
        }

        if ($player->play_session_id !== $session->id) {
            return response()->json(['message' => 'Player is not in the active session'], 404);
        }

        try {
            $this->sessionService->removePlayer($session, $player);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }
}
