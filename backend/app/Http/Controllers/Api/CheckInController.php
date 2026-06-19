<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\PaymentRequiredException;
use App\Http\Controllers\Controller;
use App\Models\ClubPlayer;
use App\Models\Player;
use App\Services\CheckInService;
use App\Services\ClubPlayerService;
use App\Services\CourtService;
use App\Services\PaymentService;
use App\Services\PlayerAvailabilityService;
use App\Services\SessionService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CheckInController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(
        private CheckInService $checkInService,
        private ClubPlayerService $clubPlayerService,
        private SessionService $sessionService,
        private PaymentService $paymentService,
        private PlayerAvailabilityService $availabilityService,
        private CourtService $courtService,
    ) {}

    public function session(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        return response()->json($this->checkInService->sessionInfo($session));
    }

    public function sessionPlayers(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        return response()->json([
            'players' => $this->checkInService->sessionRoster(
                $session,
                $request->query('search'),
            ),
        ]);
    }

    public function players(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        return response()->json([
            'players' => $this->checkInService->listPlayers(
                $session,
                $request->query('search'),
            ),
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'skill_level' => 'required|in:beginner,novice,intermediate,advanced',
            'gender' => 'required|in:male,female',
            'is_guest' => 'sometimes|boolean',
            'join_session' => 'sometimes|boolean',
        ]);

        $isGuest = (bool) ($validated['is_guest'] ?? false);

        try {
            $clubPlayer = $isGuest
                ? $this->clubPlayerService->registerGuest(
                    $validated['name'],
                    $validated['skill_level'],
                    $validated['gender'],
                )
                : $this->clubPlayerService->register(
                    $validated['name'],
                    $validated['skill_level'],
                    $validated['gender'],
                );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $joined = false;
        $status = null;
        if ($validated['join_session'] ?? true) {
            [$joined, $status] = $this->tryJoin($session, $clubPlayer);
        }

        return response()->json([
            'player' => $this->clubPlayerService->formatClubPlayer($clubPlayer),
            'joined' => $joined,
            'status' => $status,
        ], 201);
    }

    public function join(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        $validated = $request->validate([
            'club_player_id' => 'required|exists:club_players,id',
        ]);

        $clubPlayer = ClubPlayer::query()->findOrFail($validated['club_player_id']);

        $alreadyInSession = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayer->id)
            ->exists();

        if ($alreadyInSession) {
            return response()->json([
                'message' => 'You are already checked in',
                'status' => $this->checkInService->playerStatus($session, $clubPlayer->id),
            ]);
        }

        $sessionPlayer = $this->paymentService->ensureRegistration($session, $clubPlayer);
        if (! $sessionPlayer->canJoinQueue()) {
            return response()->json([
                'message' => 'Payment required at the registration desk',
                'joined' => false,
                'status' => $this->checkInService->playerStatus($session, $clubPlayer->id),
            ], 402);
        }

        try {
            $player = $this->sessionService->activateClubPlayerInSession($session, $clubPlayer);
        } catch (PaymentRequiredException|\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $this->broadcastState($session->fresh());

        return response()->json([
            'player' => [
                'id' => $player->id,
                'name' => $clubPlayer->publicName(),
                'clubPlayerId' => $clubPlayer->id,
            ],
            'status' => $this->checkInService->playerStatus($session, $clubPlayer->id),
        ], 201);
    }

    public function status(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        $validated = $request->validate([
            'club_player_id' => 'sometimes|exists:club_players,id',
            'player_id' => 'sometimes|exists:players,id',
        ]);

        if (! isset($validated['club_player_id']) && ! isset($validated['player_id'])) {
            return response()->json(['message' => 'club_player_id or player_id is required'], 400);
        }

        return response()->json(
            $this->checkInService->playerStatus(
                $session,
                isset($validated['club_player_id']) ? (int) $validated['club_player_id'] : null,
                isset($validated['player_id']) ? (int) $validated['player_id'] : null,
            ),
        );
    }

    public function stepOut(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        $validated = $request->validate([
            'club_player_id' => 'sometimes|exists:club_players,id',
            'player_id' => 'sometimes|exists:players,id',
        ]);

        $player = $this->checkInService->resolvePlayer(
            $session,
            isset($validated['club_player_id']) ? (int) $validated['club_player_id'] : null,
            isset($validated['player_id']) ? (int) $validated['player_id'] : null,
        );

        if (! $player) {
            return response()->json(['message' => 'Player not found in session'], 404);
        }

        try {
            $this->availabilityService->stepOut($session, $player);
            $this->courtService->tryAutoAssignAvailableCourts($session->fresh());
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $this->broadcastState($session->fresh());

        return response()->json(
            $this->checkInService->formatPlayerStatus($session, $player->fresh()),
        );
    }

    public function stepBack(Request $request): JsonResponse
    {
        try {
            $session = $this->checkInService->resolveSession($request);
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 404);
        }

        $validated = $request->validate([
            'club_player_id' => 'sometimes|exists:club_players,id',
            'player_id' => 'sometimes|exists:players,id',
        ]);

        $player = $this->checkInService->resolvePlayer(
            $session,
            isset($validated['club_player_id']) ? (int) $validated['club_player_id'] : null,
            isset($validated['player_id']) ? (int) $validated['player_id'] : null,
        );

        if (! $player) {
            return response()->json(['message' => 'Player not found in session'], 404);
        }

        try {
            $this->availabilityService->stepBack($session, $player);
            $this->courtService->tryAutoAssignAvailableCourts($session->fresh());
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        $this->broadcastState($session->fresh());

        return response()->json(
            $this->checkInService->formatPlayerStatus($session, $player->fresh()),
        );
    }

    /**
     * @return array{0: bool, 1: array<string, mixed>|null}
     */
    private function tryJoin($session, ClubPlayer $clubPlayer): array
    {
        $exists = Player::query()
            ->active()
            ->where('play_session_id', $session->id)
            ->where('club_player_id', $clubPlayer->id)
            ->exists();

        if ($exists) {
            return [false, $this->checkInService->playerStatus($session, $clubPlayer->id)];
        }

        $sessionPlayer = $this->paymentService->ensureRegistration($session, $clubPlayer);
        if (! $sessionPlayer->canJoinQueue()) {
            return [false, $this->checkInService->playerStatus($session, $clubPlayer->id)];
        }

        try {
            $this->sessionService->activateClubPlayerInSession($session, $clubPlayer);
            $this->broadcastState($session->fresh());

            return [true, $this->checkInService->playerStatus($session, $clubPlayer->id)];
        } catch (PaymentRequiredException|\InvalidArgumentException|\RuntimeException) {
            return [false, $this->checkInService->playerStatus($session, $clubPlayer->id)];
        }
    }
}
