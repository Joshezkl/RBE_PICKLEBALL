<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Court;
use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use App\Services\ChallengeCourtService;
use App\Services\CourtService;
use App\Services\MatchService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MatchController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(
        private MatchService $matchService,
        private CourtService $courtService,
        private ChallengeCourtService $challengeCourtService,
    ) {}

    public function score(Request $request, PlaySession $session, MatchGame $match): JsonResponse
    {
        if ($match->play_session_id !== $session->id) {
            return response()->json(['message' => 'Match not in this session'], 404);
        }

        $validated = $request->validate([
            'score_a' => 'required|integer|min:0',
            'score_b' => 'required|integer|min:0',
        ]);

        try {
            $this->matchService->finishMatch(
                $session,
                $match,
                $validated['score_a'],
                $validated['score_b'],
            );
            $this->challengeCourtService->handleMatchFinished($session->fresh(), $match->fresh());
            $this->courtService->tryAutoAssignAvailableCourts($session->fresh());
            $this->challengeCourtService->tryAutoAssign($session->fresh());
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function assignNext(PlaySession $session, Court $court): JsonResponse
    {
        if ($court->play_session_id !== $session->id) {
            return response()->json(['message' => 'Court not in this session'], 404);
        }

        try {
            $assigned = $this->courtService->assignNextUp($session, $court);
            if (! $assigned) {
                return response()->json(['message' => 'Not enough players in queue for next assignment'], 422);
            }
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function assign(Request $request, PlaySession $session, Court $court): JsonResponse
    {
        if ($court->play_session_id !== $session->id) {
            return response()->json(['message' => 'Court not in this session'], 404);
        }

        $validated = $request->validate([
            'player_ids' => 'required|array',
            'player_ids.*' => 'integer',
        ]);

        try {
            $this->courtService->manualAssign($session, $court, $validated['player_ids']);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function removePlayer(PlaySession $session, Court $court, Player $player): JsonResponse
    {
        if ($court->play_session_id !== $session->id) {
            return response()->json(['message' => 'Court not in this session'], 404);
        }

        if ($player->play_session_id !== $session->id) {
            return response()->json(['message' => 'Player not in this session'], 404);
        }

        try {
            $this->courtService->removePlayerFromCourt($session, $court, $player);
            $this->courtService->tryAutoAssignAvailableCourts($session->fresh());
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function swapPlayers(Request $request, PlaySession $session, Court $court): JsonResponse
    {
        if ($court->play_session_id !== $session->id) {
            return response()->json(['message' => 'Court not in this session'], 404);
        }

        $validated = $request->validate([
            'player_a_id' => 'required|integer',
            'player_b_id' => 'required|integer|different:player_a_id',
        ]);

        try {
            $this->courtService->swapMatchPlayers(
                $session,
                $court,
                $validated['player_a_id'],
                $validated['player_b_id'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }
}
