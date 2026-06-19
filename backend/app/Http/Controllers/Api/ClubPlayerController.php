<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ClubPlayer;
use App\Models\Player;
use App\Models\PlaySession;
use App\Models\SessionPlayer;
use App\Services\ClubPlayerService;
use App\Services\PlayerProfileService;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ClubPlayerController extends Controller
{
    public function __construct(
        private ClubPlayerService $clubPlayerService,
        private PlayerProfileService $playerProfileService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $search = $request->query('search');
        $activeSession = PlaySession::query()->where('status', 'active')->first();

        $sessionPlayersByClubId = collect();
        $activeRosterClubIds = collect();
        if ($activeSession) {
            $sessionPlayersByClubId = SessionPlayer::query()
                ->where('play_session_id', $activeSession->id)
                ->get()
                ->keyBy('club_player_id');

            $activeRosterClubIds = Player::query()
                ->active()
                ->where('play_session_id', $activeSession->id)
                ->whereNotNull('club_player_id')
                ->pluck('club_player_id');
        }

        $players = $this->clubPlayerService->list($search)->map(function (ClubPlayer $clubPlayer) use (
            $sessionPlayersByClubId,
            $activeRosterClubIds,
        ) {
            $formatted = $this->clubPlayerService->formatClubPlayer(
                $clubPlayer,
                $sessionPlayersByClubId->get($clubPlayer->id),
            );
            $formatted['inCurrentSession'] = $activeRosterClubIds->contains($clubPlayer->id);

            return $formatted;
        });

        return response()->json([
            'players' => $players,
            'activeSessionId' => $activeSession?->id,
        ]);
    }

    public function show(ClubPlayer $clubPlayer): JsonResponse
    {
        return response()->json(
            $this->playerProfileService->build($clubPlayer),
        );
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
            'skill_level' => 'required|in:beginner,novice,intermediate,advanced',
            'gender' => 'required|in:male,female',
        ]);

        try {
            $clubPlayer = $this->clubPlayerService->register(
                $validated['name'],
                $validated['skill_level'],
                $validated['gender'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'player' => $this->clubPlayerService->formatClubPlayer($clubPlayer),
        ], 201);
    }

    public function destroy(ClubPlayer $clubPlayer): JsonResponse
    {
        try {
            $this->clubPlayerService->delete($clubPlayer);
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        } catch (QueryException $e) {
            return response()->json([
                'message' => 'Could not delete this player because they are still linked to other records.',
            ], 422);
        }

        return response()->json(['message' => 'Player deleted']);
    }
}
