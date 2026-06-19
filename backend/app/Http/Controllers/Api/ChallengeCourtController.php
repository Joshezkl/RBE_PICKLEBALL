<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Court;
use App\Models\PlaySession;
use App\Services\ChallengeCourtService;
use App\Services\CourtService;
use App\Services\MatchService;
use App\Support\BroadcastsSessionState;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChallengeCourtController extends Controller
{
    use BroadcastsSessionState;

    public function __construct(
        private ChallengeCourtService $challengeCourtService,
        private CourtService $courtService,
        private MatchService $matchService,
    ) {}

    public function configure(Request $request, PlaySession $session): JsonResponse
    {
        $validated = $request->validate([
            'court_numbers' => 'present|array|max:2',
            'court_numbers.*' => 'integer|min:1',
        ]);

        try {
            $this->challengeCourtService->configureCourts(
                $session,
                $validated['court_numbers'],
            );
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function open(PlaySession $session): JsonResponse
    {
        $this->challengeCourtService->open($session);

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function close(PlaySession $session): JsonResponse
    {
        $this->challengeCourtService->close($session);

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function join(Request $request, PlaySession $session): JsonResponse
    {
        $validated = $request->validate([
            'player_id' => 'required|integer',
            'partner_id' => 'required|integer',
        ]);

        try {
            $this->challengeCourtService->joinTeam(
                $session,
                $validated['player_id'],
                $validated['partner_id'],
            );
            $this->challengeCourtService->tryAutoAssign($session->fresh());
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function returnToSession(PlaySession $session, int $team): JsonResponse
    {
        try {
            $this->challengeCourtService->returnTeamToSession($session, $team);
            $this->courtService->tryAutoAssignAvailableCourts($session->fresh());
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function removeTeam(PlaySession $session, int $team): JsonResponse
    {
        try {
            $this->challengeCourtService->removeTeam($session, $team);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }

    public function reorder(Request $request, PlaySession $session): JsonResponse
    {
        $validated = $request->validate([
            'team_ids' => 'required|array|min:1',
            'team_ids.*' => 'integer',
        ]);

        try {
            $this->challengeCourtService->reorderTeams($session, $validated['team_ids']);
        } catch (\InvalidArgumentException $e) {
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
            if ($this->challengeCourtService->courtState($session, $court)['canNextChallenger'] ?? false) {
                $assigned = $this->challengeCourtService->assignNextChallenger($session, $court);
                if (! $assigned) {
                    return response()->json([
                        'message' => 'No challengers are waiting in the Challenge Court queue',
                    ], 422);
                }
            } else {
                $assigned = $this->challengeCourtService->assignNextMatch($session, $court);
                if (! $assigned) {
                    return response()->json([
                        'message' => 'Need at least two teams in the Challenge Court queue',
                    ], 422);
                }
            }
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->broadcastState($session->fresh()));
    }
}
