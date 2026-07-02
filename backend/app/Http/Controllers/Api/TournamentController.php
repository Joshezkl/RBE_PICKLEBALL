<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ClubPlayer;
use App\Models\Tournament;
use App\Models\TournamentMatch;
use App\Models\TournamentTeam;
use App\Services\TournamentCourtService;
use App\Services\TournamentDrawLotsService;
use App\Services\TournamentMatchService;
use App\Services\TournamentService;
use App\Services\TournamentStateService;
use App\Support\TournamentCategory as TournamentCategorySupport;
use App\Support\TournamentGroup;
use App\Support\TournamentSkillLevel;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TournamentController extends Controller
{
    public function __construct(
        private TournamentService $tournamentService,
        private TournamentStateService $stateService,
        private TournamentMatchService $matchService,
        private TournamentCourtService $courtService,
        private TournamentDrawLotsService $drawLotsService,
    ) {}

    public function index(): JsonResponse
    {
        return response()->json([
            'tournaments' => $this->tournamentService->list(),
            'skillLevels' => collect(TournamentSkillLevel::ALL)
                ->map(fn (string $level) => [
                    'key' => $level,
                    'label' => TournamentSkillLevel::label($level),
                ])
                ->values(),
            'availableCategories' => TournamentCategorySupport::catalogPayload(),
            'categoryGroups' => TournamentCategorySupport::groupedCatalogPayload(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:120',
            'group_count' => 'sometimes|integer|min:1|max:'.TournamentGroup::MAX_GROUPS,
            'court_count' => 'sometimes|integer|min:1|max:12',
            'categories' => 'sometimes|array',
            'categories.*' => 'string',
        ]);

        $tournament = $this->tournamentService->create($validated);

        return response()->json($this->stateService->build($tournament), 201);
    }

    public function show(Tournament $tournament): JsonResponse
    {
        return response()->json($this->stateService->buildCached($tournament));
    }

    public function active(): JsonResponse
    {
        $tournament = Tournament::query()
            ->whereIn('status', ['round_robin', 'single_elimination', 'final_round_robin'])
            ->orderByDesc('started_at')
            ->first();

        if ($tournament === null) {
            return response()->json(['message' => 'No live tournament'], 404);
        }

        return response()->json($this->stateService->buildCached($tournament));
    }

    public function update(Request $request, Tournament $tournament): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:120',
            'group_count' => 'sometimes|integer|min:1|max:'.TournamentGroup::MAX_GROUPS,
            'court_count' => 'sometimes|integer|min:1|max:12',
            'categories' => 'sometimes|array',
            'categories.*' => 'string',
        ]);

        try {
            $tournament = $this->tournamentService->update($tournament, $validated);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament));
    }

    public function start(Tournament $tournament): JsonResponse
    {
        try {
            $tournament = $this->tournamentService->start($tournament);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament));
    }

    public function registerTeam(Request $request, Tournament $tournament, string $categoryKey): JsonResponse
    {
        $validated = $request->validate([
            'player_ids' => 'sometimes|array|min:1|max:2',
            'player_ids.*' => 'integer|exists:club_players,id',
            'player_names' => 'sometimes|array|min:1|max:2',
            'player_names.*' => 'required|string|max:100',
            'genders' => 'sometimes|array|min:1|max:2',
            'genders.*' => 'required|in:male,female',
        ]);

        $hasIds = ! empty($validated['player_ids']);
        $hasNames = ! empty($validated['player_names']);

        if ($hasIds === $hasNames) {
            return response()->json([
                'message' => 'Provide either player_names or player_ids',
            ], 422);
        }

        try {
            if ($hasNames) {
                $this->tournamentService->registerTeamFromNames(
                    $tournament,
                    $categoryKey,
                    $validated['player_names'],
                    $validated['genders'] ?? [],
                );
            } else {
                $this->tournamentService->registerTeam(
                    $tournament,
                    $categoryKey,
                    $validated['player_ids'],
                );
            }
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }

    public function drawLots(Request $request, Tournament $tournament, string $categoryKey): JsonResponse
    {
        $validated = $request->validate([
            'player_names' => 'required|array|min:2',
            'player_names.*' => 'required|string|max:100',
            'genders' => 'sometimes|array',
            'genders.*' => 'required|in:male,female',
            'preview' => 'sometimes|boolean',
        ]);

        $playerNames = $validated['player_names'];
        $genders = $validated['genders'] ?? null;

        if ($genders !== null && count($genders) !== count($playerNames)) {
            return response()->json([
                'message' => 'genders must include one value per player when provided',
            ], 422);
        }

        try {
            if ($validated['preview'] ?? false) {
                $pairs = $this->drawLotsService->buildPairs(
                    $categoryKey,
                    $playerNames,
                    $genders,
                );

                return response()->json(['pairs' => $pairs]);
            }

            $pairs = $this->drawLotsService->drawAndRegister(
                $tournament,
                $categoryKey,
                $playerNames,
                $genders,
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'pairs' => $pairs,
            'state' => $this->stateService->build($tournament->fresh()),
        ]);
    }

    public function removeTeam(Tournament $tournament, TournamentTeam $team): JsonResponse
    {
        try {
            $this->tournamentService->removeTeam($tournament, $team);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }

    public function updatePlayer(
        Request $request,
        Tournament $tournament,
        ClubPlayer $clubPlayer,
    ): JsonResponse {
        $validated = $request->validate([
            'name' => 'required|string|max:100',
        ]);

        try {
            $this->tournamentService->updatePlayerName(
                $tournament,
                $clubPlayer,
                $validated['name'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }

    public function destroy(Tournament $tournament): JsonResponse
    {
        $this->tournamentService->delete($tournament);

        return response()->json(null, 204);
    }

    public function score(Request $request, Tournament $tournament, TournamentMatch $tournamentMatch): JsonResponse
    {
        $validated = $request->validate([
            'score_a' => 'required|integer|min:0|max:99',
            'score_b' => 'required|integer|min:0|max:99',
        ]);

        try {
            $this->matchService->score(
                $tournament,
                $tournamentMatch,
                $validated['score_a'],
                $validated['score_b'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }

    public function activateCourt(
        Tournament $tournament,
        TournamentMatch $tournamentMatch,
    ): JsonResponse {
        try {
            $this->courtService->activateOnCourt($tournament, $tournamentMatch);
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }

    public function assignCourt(
        Request $request,
        Tournament $tournament,
        TournamentMatch $tournamentMatch,
    ): JsonResponse {
        $validated = $request->validate([
            'court_number' => 'required|integer|min:1|max:12',
        ]);

        try {
            $this->courtService->assignMatchToCourt(
                $tournament,
                $tournamentMatch,
                (int) $validated['court_number'],
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }

    public function replaceCourt(
        Request $request,
        Tournament $tournament,
        TournamentMatch $tournamentMatch,
    ): JsonResponse {
        $validated = $request->validate([
            'court_number' => 'required|integer|min:1|max:12',
        ]);

        try {
            $this->courtService->replaceCourtMatch(
                $tournament,
                (int) $validated['court_number'],
                $tournamentMatch,
            );
        } catch (\InvalidArgumentException|\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json($this->stateService->build($tournament->fresh()));
    }
}
