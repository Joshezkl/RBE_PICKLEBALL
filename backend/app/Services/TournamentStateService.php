<?php

namespace App\Services;

use App\Models\Tournament;
use App\Models\TournamentCategory;
use App\Models\TournamentMatch;
use App\Models\TournamentTeam;
use App\Support\TournamentCategory as TournamentCategorySupport;
use App\Support\TournamentGroup;
use App\Support\TournamentSkillLevel;
use Illuminate\Support\Facades\Cache;

class TournamentStateService
{
    public function __construct(
        private TournamentStandingsService $standingsService,
        private TournamentScheduleService $scheduleService,
        private TournamentCourtService $courtService,
    ) {}

    public static function cacheKey(int $tournamentId): string
    {
        return "rpc:tournament:state:{$tournamentId}";
    }

    public static function activeCacheKey(): string
    {
        return 'rpc:tournament:active';
    }

    public static function invalidate(int $tournamentId): void
    {
        Cache::forget(self::cacheKey($tournamentId));
        Cache::forget(self::activeCacheKey());
    }

    /**
     * Cached tournament state for high-frequency read endpoints.
     */
    public function buildCached(Tournament $tournament): array
    {
        $ttl = (int) config('rpc.cache.tournament_ttl', 5);

        if ($ttl <= 0) {
            return $this->build($tournament);
        }

        return Cache::remember(
            self::cacheKey($tournament->id),
            $ttl,
            fn () => $this->build($tournament),
        );
    }

    /**
     * Cached full state for the live tournament (/tournaments/active).
     */
    public function buildActiveCached(Tournament $tournament): array
    {
        $ttl = (int) config('rpc.cache.tournament_ttl', 5);

        if ($ttl <= 0) {
            return $this->build($tournament);
        }

        return Cache::remember(
            self::activeCacheKey(),
            $ttl,
            fn () => $this->build($tournament),
        );
    }

    /**
     * Cached "no live tournament" payload for /tournaments/active.
     *
     * @return array{active: false, message: string}
     */
    public function buildActiveEmptyCached(): array
    {
        $payload = [
            'active' => false,
            'message' => 'No live tournament',
        ];

        $ttl = (int) config('rpc.cache.tournament_ttl', 5);

        if ($ttl <= 0) {
            return $payload;
        }

        return Cache::remember(
            self::activeCacheKey(),
            $ttl,
            fn () => $payload,
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function build(Tournament $tournament): array
    {
        $tournament->load(['categories']);

        foreach ($tournament->categories->where('is_enabled', true) as $category) {
            if ($category->phase === 'single_elimination') {
                $this->scheduleService->repairThreeTeamPlayoffFormat($category);
            }

            if (in_array($category->phase, ['single_elimination', 'completed'], true)) {
                $this->scheduleService->ensureThirdPlaceMatchForScoring($category);
            }

            if ($category->phase === 'completed') {
                $this->scheduleService->backfillPlacementsIfNeeded($category);
            }
        }

        $tournament->refresh();

        foreach ($tournament->categories->where('is_enabled', true) as $category) {
            if ($category->phase === 'final_round_robin') {
                $tournament->update(['status' => 'final_round_robin']);
                break;
            }
        }

        $tournament->load([
            'categories.teams.members.clubPlayer',
            'matches.teamA.members.clubPlayer',
            'matches.teamB.members.clubPlayer',
        ]);

        $configured = $tournament->categories->keyBy('category_key');

        $categories = $tournament->categories
            ->where('is_enabled', true)
            ->sortBy(fn ($row) => TournamentCategorySupport::label($row->category_key))
            ->map(function ($row) use ($tournament) {
                $key = $row->category_key;

                $teams = $tournament->teams
                    ->where('tournament_category_id', $row->id)
                    ->values();

                $matches = $tournament->matches
                    ->where('tournament_category_id', $row->id)
                    ->sortBy(['phase', 'round_index', 'match_index'])
                    ->values();

                return [
                    'key' => $key,
                    'label' => TournamentCategorySupport::label($key),
                    'eventKey' => TournamentCategorySupport::eventKey($key),
                    'eventLabel' => TournamentCategorySupport::eventLabel(TournamentCategorySupport::eventKey($key)),
                    'skillLevel' => TournamentCategorySupport::skillLevel($key),
                    'skillLabel' => TournamentSkillLevel::label(TournamentCategorySupport::skillLevel($key)),
                    'division' => TournamentCategorySupport::division($key),
                    'isEnabled' => true,
                    'phase' => $row->phase,
                    'categoryId' => $row->id,
                    'teams' => $teams->map(fn (TournamentTeam $team) => $this->formatTeam($team))->all(),
                    'standings' => $row->phase !== 'setup'
                        ? $this->standingsService->standingsPayload($row)
                        : [],
                    'groups' => $row->phase !== 'setup'
                        ? $this->buildGroupsPayload($row, $tournament, $matches)
                        : $this->emptyGroupsPayload((int) $tournament->group_count),
                    'matches' => $matches->map(fn (TournamentMatch $match) => $this->formatMatch($match))->all(),
                    'bracket' => $this->buildBracketPayload($matches),
                    'placements' => $this->scheduleService->buildPlacementsPayload($row),
                    'thirdPlaceMatch' => $this->formatThirdPlaceMatch($matches),
                ];
            })
            ->values()
            ->all();

        return [
            'tournament' => [
                'id' => $tournament->id,
                'name' => $tournament->name,
                'status' => $tournament->status,
                'groupCount' => (int) $tournament->group_count,
                'registrationOpen' => in_array($tournament->status, ['draft', 'setup'], true),
                'groupLabels' => collect(TournamentGroup::keysForCount((int) $tournament->group_count))
                    ->map(fn (string $key) => TournamentGroup::label($key))
                    ->all(),
                'courtCount' => $tournament->court_count,
                'format' => 'group_round_robin_then_single_elimination',
                'startedAt' => $tournament->started_at?->toIso8601String(),
                'endedAt' => $tournament->ended_at?->toIso8601String(),
            ],
            'skillLevels' => collect(TournamentSkillLevel::ALL)
                ->map(fn (string $level) => [
                    'key' => $level,
                    'label' => TournamentSkillLevel::label($level),
                ])
                ->values()
                ->all(),
            'availableCategories' => TournamentCategorySupport::catalogPayload(),
            'categoryGroups' => TournamentCategorySupport::groupedCatalogPayload(),
            'categories' => $categories,
            'display' => [
                'courts' => $this->courtService->buildCourtsPayload($tournament),
                'upNext' => $this->courtService->buildUpNextPayload($tournament),
                'recentResults' => $this->courtService->buildRecentResultsPayload($tournament),
                'activeCategory' => $this->courtService->buildActiveCategoryPayload(
                    $this->courtService->activeCategory($tournament),
                ),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function formatTeam(TournamentTeam $team): array
    {
        return [
            'id' => $team->id,
            'displayName' => $team->display_name,
            'groupKey' => $team->group_key,
            'seed' => $team->seed,
            'status' => $team->status,
            'wins' => $team->wins,
            'losses' => $team->losses,
            'pointsScored' => $team->points_scored,
            'pointsAllowed' => $team->points_allowed,
            'pointDifferential' => $team->pointDifferential(),
            'players' => $team->members->map(fn ($member) => [
                'id' => $member->club_player_id,
                'name' => $member->clubPlayer?->publicName() ?? 'Player',
            ])->all(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function formatMatch(TournamentMatch $match): array
    {
        return [
            'id' => $match->id,
            'phase' => $match->phase,
            'groupKey' => $match->group_key,
            'roundIndex' => $match->round_index,
            'matchIndex' => $match->match_index,
            'status' => $match->status,
            'courtNumber' => $match->court_number,
            'scoreA' => $match->score_a,
            'scoreB' => $match->score_b,
            'teamA' => $match->teamA ? $this->formatTeam($match->teamA) : null,
            'teamB' => $match->teamB ? $this->formatTeam($match->teamB) : null,
            'winnerTeamId' => $match->winner_team_id,
            'feedsIntoMatchId' => $match->feeds_into_match_id,
            'feedSlot' => $match->feed_slot,
        ];
    }

    /**
     * @param  \Illuminate\Support\Collection<int, TournamentMatch>  $matches
     * @return array<string, mixed>|null
     */
    private function formatThirdPlaceMatch($matches): ?array
    {
        $thirdPlace = $matches->firstWhere('phase', 'third_place');

        return $thirdPlace ? $this->formatMatch($thirdPlace) : null;
    }

    /**
     * @param  \Illuminate\Support\Collection<int, TournamentMatch>  $matches
     * @return array{rounds: list<array{roundIndex: int, label: string, matches: list<array<string, mixed>>}>}|null
     */
    private function buildBracketPayload($matches): ?array
    {
        $elimMatches = $matches
            ->where('phase', 'single_elimination')
            ->values();

        if ($elimMatches->isEmpty()) {
            return null;
        }

        $maxRound = (int) $elimMatches->max('round_index');

        $rounds = $elimMatches
            ->groupBy('round_index')
            ->sortKeys()
            ->map(function ($roundMatches, $roundIndex) use ($maxRound) {
                return [
                    'roundIndex' => (int) $roundIndex,
                    'label' => $this->scheduleService->roundLabel((int) $roundIndex, $maxRound),
                    'matches' => $roundMatches
                        ->sortBy('match_index')
                        ->values()
                        ->map(fn (TournamentMatch $match) => $this->formatMatch($match))
                        ->all(),
                ];
            })
            ->values()
            ->all();

        return ['rounds' => $rounds];
    }

    /**
     * @return list<array{key: string, label: string, standings: list<array<string, mixed>>, matches: list<array<string, mixed>>}>
     */
    private function buildGroupsPayload(
        TournamentCategory $category,
        Tournament $tournament,
        $matches,
    ): array {
        $groupCount = (int) $tournament->group_count;

        return collect(TournamentGroup::keysForCount($groupCount))
            ->map(function (string $groupKey) use ($category, $matches, $groupCount) {
                $groupMatches = $matches
                    ->where('phase', 'round_robin')
                    ->where('group_key', $groupKey)
                    ->sortBy('match_index')
                    ->values();

                return [
                    'key' => $groupKey,
                    'label' => TournamentGroup::label($groupKey),
                    'standings' => $this->standingsService->standingsPayloadForGroup($category, $groupKey),
                    'matches' => $groupMatches
                        ->map(fn (TournamentMatch $match) => $this->formatMatch($match))
                        ->all(),
                ];
            })
            ->when(
                $matches->where('phase', 'final_round_robin')->isNotEmpty(),
                function ($collection) use ($category, $matches) {
                    $finalMatches = $matches
                        ->where('phase', 'final_round_robin')
                        ->sortBy('match_index')
                        ->values();

                    return $collection->push([
                        'key' => 'final',
                        'label' => 'Final Round Robin',
                        'standings' => $this->standingsService->finalRoundRobinStandingsPayload($category),
                        'matches' => $finalMatches
                            ->map(fn (TournamentMatch $match) => $this->formatMatch($match))
                            ->all(),
                    ]);
                },
            )
            ->values()
            ->all();
    }

    /**
     * @return list<array{key: string, label: string, standings: list<array<string, mixed>>, matches: list<array<string, mixed>>}>
     */
    private function emptyGroupsPayload(int $groupCount): array
    {
        return collect(TournamentGroup::keysForCount($groupCount))
            ->map(fn (string $groupKey) => [
                'key' => $groupKey,
                'label' => TournamentGroup::label($groupKey),
                'standings' => [],
                'matches' => [],
            ])
            ->all();
    }
}
