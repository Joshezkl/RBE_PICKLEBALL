<?php

namespace App\Services;

use App\Models\Tournament;
use App\Models\TournamentCategory;
use App\Models\TournamentMatch;
use App\Support\TournamentCategory as TournamentCategorySupport;
use App\Support\TournamentGroup;
use Illuminate\Support\Collection;

class TournamentCourtService
{
    public function clearCourtAssignments(Tournament $tournament): void
    {
        TournamentMatch::query()
            ->where('tournament_id', $tournament->id)
            ->whereNotNull('court_number')
            ->whereIn('status', ['scheduled', 'on_court'])
            ->update([
                'court_number' => null,
                'status' => 'scheduled',
            ]);
    }

    public function syncAssignments(
        Tournament $tournament,
        ?string $preferredGroupKey = null,
        ?int $freedCourtNumber = null,
        array $justFinishedTeamIds = [],
    ): void {
        $tournament->refresh();

        if (! in_array($tournament->status, ['round_robin', 'single_elimination', 'final_round_robin'], true)) {
            return;
        }

        $courtCount = (int) $tournament->court_count;

        for ($courtNumber = 1; $courtNumber <= $courtCount; $courtNumber++) {
            $occupied = TournamentMatch::query()
                ->where('tournament_id', $tournament->id)
                ->where('court_number', $courtNumber)
                ->whereIn('status', ['scheduled', 'on_court'])
                ->exists();

            if ($occupied) {
                continue;
            }

            $groupPreference = $freedCourtNumber === $courtNumber
                ? $preferredGroupKey
                : null;

            $match = $this->pickNextMatch(
                $tournament,
                $courtNumber,
                $groupPreference,
                $justFinishedTeamIds,
            );

            if ($match === null) {
                continue;
            }

            $match->update([
                'court_number' => $courtNumber,
                'status' => 'on_court',
            ]);
        }
    }

    public function activateOnCourt(Tournament $tournament, TournamentMatch $match): void
    {
        if ($match->tournament_id !== $tournament->id) {
            throw new \InvalidArgumentException('Match does not belong to this tournament');
        }

        if ($match->status !== 'scheduled' || $match->court_number === null) {
            throw new \RuntimeException('Match is not queued for this court');
        }

        $match->update(['status' => 'on_court']);
    }

    public function assignMatchToCourt(
        Tournament $tournament,
        TournamentMatch $match,
        int $courtNumber,
    ): void {
        if ($match->tournament_id !== $tournament->id) {
            throw new \InvalidArgumentException('Match does not belong to this tournament');
        }

        if (! in_array($tournament->status, ['round_robin', 'single_elimination', 'final_round_robin'], true)) {
            throw new \RuntimeException('Tournament is not in an active court phase');
        }

        $courtCount = (int) $tournament->court_count;

        if ($courtNumber < 1 || $courtNumber > $courtCount) {
            throw new \InvalidArgumentException('Invalid court number');
        }

        if ($match->status !== 'scheduled') {
            throw new \RuntimeException('Match is not available for court assignment');
        }

        if ($match->court_number !== null) {
            throw new \RuntimeException('Match is already assigned to a court');
        }

        if ($match->team_a_id === null || $match->team_b_id === null) {
            throw new \RuntimeException('Match is missing teams');
        }

        $category = $this->activeCategory($tournament);
        if ($category !== null && $match->tournament_category_id === $category->id) {
            $activeGroups = $this->activeRoundRobinGroupKeys($tournament, $category);
            if (
                $category->phase === 'round_robin'
                && $match->group_key !== null
                && ! in_array($match->group_key, $activeGroups, true)
            ) {
                throw new \RuntimeException(
                    'Earlier groups must finish round robin before scheduling this group.',
                );
            }
        }

        $occupied = TournamentMatch::query()
            ->where('tournament_id', $tournament->id)
            ->where('court_number', $courtNumber)
            ->whereIn('status', ['scheduled', 'on_court'])
            ->exists();

        if ($occupied) {
            throw new \RuntimeException("Court {$courtNumber} is not available");
        }

        $match->update([
            'court_number' => $courtNumber,
            'status' => 'on_court',
        ]);
    }

    public function activeCategory(Tournament $tournament): ?TournamentCategory
    {
        return $tournament->categories()
            ->where('is_enabled', true)
            ->whereNotIn('phase', ['setup', 'completed'])
            ->get()
            ->sortBy(fn (TournamentCategory $category) => TournamentCategorySupport::label($category->category_key))
            ->first();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function buildCourtsPayload(Tournament $tournament): array
    {
        $courtCount = (int) $tournament->court_count;

        $assigned = TournamentMatch::query()
            ->where('tournament_id', $tournament->id)
            ->whereNotNull('court_number')
            ->whereIn('status', ['scheduled', 'on_court'])
            ->with(['teamA', 'teamB', 'category'])
            ->get()
            ->keyBy('court_number');

        $courts = [];

        for ($courtNumber = 1; $courtNumber <= $courtCount; $courtNumber++) {
            $match = $assigned->get($courtNumber);

            $courts[] = [
                'courtNumber' => $courtNumber,
                'status' => $match === null
                    ? 'available'
                    : ($match->status === 'on_court' ? 'in_match' : 'assigned'),
                'match' => $match ? $this->formatCourtMatch($match) : null,
            ];
        }

        return $courts;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function buildUpNextPayload(Tournament $tournament, int $limit = 8): array
    {
        $category = $this->activeCategory($tournament);

        if ($category === null) {
            return [];
        }

        $busyTeams = $this->busyTeamIds($tournament);

        $candidatesQuery = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('status', 'scheduled')
            ->whereNull('court_number')
            ->whereNotNull('team_a_id')
            ->whereNotNull('team_b_id');

        $this->applyActiveGroupScope($tournament, $category, $candidatesQuery);

        $candidates = $candidatesQuery->get();

        $sorted = $this->sortCandidatesByRest($category, $candidates);

        $ready = $sorted->filter(
            fn (TournamentMatch $match) => ! $this->matchInvolvesAnyTeam($match, $busyTeams),
        );
        $waiting = $sorted->reject(
            fn (TournamentMatch $match) => ! $this->matchInvolvesAnyTeam($match, $busyTeams),
        );

        return $ready
            ->concat($waiting)
            ->take($limit)
            ->load(['teamA', 'teamB', 'category'])
            ->map(fn (TournamentMatch $match) => [
                ...$this->formatUpNextMatch($match),
                'isReady' => ! $this->matchInvolvesAnyTeam($match, $busyTeams),
            ])
            ->values()
            ->all();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function buildRecentResultsPayload(Tournament $tournament, int $limit = 8): array
    {
        return TournamentMatch::query()
            ->where('tournament_id', $tournament->id)
            ->where('status', 'finished')
            ->whereNotNull('winner_team_id')
            ->with(['teamA', 'teamB', 'category'])
            ->orderByDesc('updated_at')
            ->limit($limit)
            ->get()
            ->map(fn (TournamentMatch $match) => [
                'id' => $match->id,
                'categoryLabel' => TournamentCategorySupport::label($match->category->category_key),
                'groupLabel' => $this->formatGroupLabel($match->group_key),
                'phase' => $match->phase,
                'teamA' => $match->teamA?->display_name,
                'teamB' => $match->teamB?->display_name,
                'scoreA' => $match->score_a,
                'scoreB' => $match->score_b,
                'winnerTeamId' => $match->winner_team_id,
            ])
            ->all();
    }

    /**
     * @return array<string, mixed>|null
     */
    public function buildActiveCategoryPayload(?TournamentCategory $category): ?array
    {
        if ($category === null) {
            return null;
        }

        return [
            'key' => $category->category_key,
            'label' => TournamentCategorySupport::label($category->category_key),
            'phase' => $category->phase,
        ];
    }

    /**
     * @param  list<int>  $justFinishedTeamIds
     */
    private function pickNextMatch(
        Tournament $tournament,
        int $courtNumber,
        ?string $preferredGroupKey,
        array $justFinishedTeamIds = [],
    ): ?TournamentMatch {
        $category = $this->activeCategory($tournament);

        if ($category === null) {
            return null;
        }

        $candidates = $this->readyMatchesQuery($tournament, $category)->get();

        if ($candidates->isEmpty()) {
            return null;
        }

        $restScores = $this->teamRestScores($category);
        $candidates = $this->sortCandidatesByRest($category, $candidates, $restScores);

        $avoidTeamIds = array_values(array_filter(array_unique($justFinishedTeamIds)));

        if ($avoidTeamIds !== []) {
            $restedCandidates = $candidates->filter(
                fn (TournamentMatch $match) => ! $this->matchInvolvesAnyTeam($match, $avoidTeamIds)
            );

            if ($restedCandidates->isNotEmpty()) {
                $candidates = $restedCandidates;
            }
        }

        if ($preferredGroupKey !== null) {
            $preferred = $candidates->firstWhere('group_key', $preferredGroupKey);
            if ($preferred !== null && ! $this->matchInvolvesAnyTeam($preferred, $avoidTeamIds)) {
                return $preferred;
            }
        }

        if ($category->phase === 'round_robin') {
            $activeGroups = $this->activeRoundRobinGroupKeys($tournament, $category);
            $preferredIndex = ($courtNumber - 1) % max(1, count($activeGroups));
            $defaultGroup = $activeGroups[$preferredIndex] ?? null;

            if ($defaultGroup !== null) {
                $fromDefaultGroup = $candidates->firstWhere('group_key', $defaultGroup);
                if ($fromDefaultGroup !== null) {
                    return $fromDefaultGroup;
                }
            }

            $fromActiveBatch = $candidates->first(
                fn (TournamentMatch $match) => in_array($match->group_key, $activeGroups, true),
            );
            if ($fromActiveBatch !== null) {
                return $fromActiveBatch;
            }

            return null;
        }

        if ($category->phase === 'final_round_robin') {
            $finalMatch = $candidates->first(
                fn (TournamentMatch $match) => $match->phase === 'final_round_robin'
            );
            if ($finalMatch !== null) {
                return $finalMatch;
            }
        }

        return $candidates->first();
    }

    /**
     * @return \Illuminate\Database\Eloquent\Builder<TournamentMatch>
     */
    private function readyMatchesQuery(Tournament $tournament, TournamentCategory $category)
    {
        $busyTeams = $this->busyTeamIds($tournament);

        $query = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('status', 'scheduled')
            ->whereNull('court_number')
            ->whereNotNull('team_a_id')
            ->whereNotNull('team_b_id');

        $this->applyActiveGroupScope($tournament, $category, $query);

        if ($busyTeams !== []) {
            $query
                ->whereNotIn('team_a_id', $busyTeams)
                ->whereNotIn('team_b_id', $busyTeams);
        }

        return $query;
    }

    /**
     * @param  Collection<int, TournamentMatch>  $candidates
     * @param  array<int, int>  $restScores
     * @return Collection<int, TournamentMatch>
     */
    private function sortCandidatesByRest(
        TournamentCategory $category,
        Collection $candidates,
        ?array $restScores = null,
    ): Collection {
        $restScores ??= $this->teamRestScores($category);

        return $candidates
            ->sort(function (TournamentMatch $left, TournamentMatch $right) use ($restScores) {
                $restCompare = $this->matchRestScore($right, $restScores)
                    <=> $this->matchRestScore($left, $restScores);

                if ($restCompare !== 0) {
                    return $restCompare;
                }

                $roundCompare = $left->round_index <=> $right->round_index;
                if ($roundCompare !== 0) {
                    return $roundCompare;
                }

                return $left->match_index <=> $right->match_index;
            })
            ->values();
    }

    /**
     * @return array<int, int>
     */
    private function teamRestScores(TournamentCategory $category): array
    {
        $finished = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('status', 'finished')
            ->orderBy('updated_at')
            ->orderBy('id')
            ->get();

        $lastFinishPosition = [];

        foreach ($finished as $position => $match) {
            if ($match->team_a_id) {
                $lastFinishPosition[$match->team_a_id] = $position;
            }

            if ($match->team_b_id) {
                $lastFinishPosition[$match->team_b_id] = $position;
            }
        }

        $total = $finished->count();
        $scores = [];

        foreach ($category->teams()->pluck('id') as $teamId) {
            if (! isset($lastFinishPosition[$teamId])) {
                $scores[$teamId] = $total + 1;

                continue;
            }

            $scores[$teamId] = $total - 1 - $lastFinishPosition[$teamId];
        }

        return $scores;
    }

    /**
     * @param  array<int, int>  $restScores
     */
    private function matchRestScore(TournamentMatch $match, array $restScores): int
    {
        $teamARest = $restScores[$match->team_a_id] ?? 0;
        $teamBRest = $restScores[$match->team_b_id] ?? 0;

        return min($teamARest, $teamBRest);
    }

    /**
     * @param  list<int>  $teamIds
     */
    private function matchInvolvesAnyTeam(TournamentMatch $match, array $teamIds): bool
    {
        return in_array($match->team_a_id, $teamIds, true)
            || in_array($match->team_b_id, $teamIds, true);
    }

    /**
     * @return list<string>
     */
    private function activeRoundRobinGroupKeys(Tournament $tournament, TournamentCategory $category): array
    {
        $allGroupKeys = TournamentGroup::keysForCount((int) $tournament->group_count);

        if ($category->phase !== 'round_robin') {
            return $allGroupKeys;
        }

        $courtCount = max(1, (int) $tournament->court_count);
        $batches = array_chunk($allGroupKeys, $courtCount);

        foreach ($batches as $batch) {
            foreach ($batch as $groupKey) {
                $hasRemaining = TournamentMatch::query()
                    ->where('tournament_category_id', $category->id)
                    ->where('group_key', $groupKey)
                    ->where('phase', 'round_robin')
                    ->whereIn('status', ['scheduled', 'on_court'])
                    ->exists();

                if ($hasRemaining) {
                    return $batch;
                }
            }
        }

        return $allGroupKeys;
    }

    /**
     * @param  \Illuminate\Database\Eloquent\Builder<TournamentMatch>  $query
     */
    private function applyActiveGroupScope(
        Tournament $tournament,
        TournamentCategory $category,
        $query,
    ): void {
        if ($category->phase !== 'round_robin') {
            return;
        }

        $activeGroups = $this->activeRoundRobinGroupKeys($tournament, $category);
        $query->whereIn('group_key', $activeGroups);
    }

    /**
     * @return list<int>
     */
    private function busyTeamIds(Tournament $tournament): array
    {
        return TournamentMatch::query()
            ->where('tournament_id', $tournament->id)
            ->whereNotNull('court_number')
            ->whereIn('status', ['scheduled', 'on_court'])
            ->get()
            ->flatMap(fn (TournamentMatch $match) => [$match->team_a_id, $match->team_b_id])
            ->filter()
            ->unique()
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function formatCourtMatch(TournamentMatch $match): array
    {
        return [
            'id' => $match->id,
            'isActive' => $match->status === 'on_court',
            'categoryLabel' => TournamentCategorySupport::label($match->category->category_key),
            'phase' => $match->phase,
            'groupKey' => $match->group_key,
            'groupLabel' => $this->formatGroupLabel($match->group_key),
            'teamA' => $match->teamA?->display_name,
            'teamB' => $match->teamB?->display_name,
            'scoreA' => $match->score_a,
            'scoreB' => $match->score_b,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function formatUpNextMatch(TournamentMatch $match): array
    {
        return [
            'id' => $match->id,
            'categoryLabel' => TournamentCategorySupport::label($match->category->category_key),
            'phase' => $match->phase,
            'groupKey' => $match->group_key,
            'groupLabel' => $this->formatGroupLabel($match->group_key),
            'teamA' => $match->teamA?->display_name,
            'teamB' => $match->teamB?->display_name,
        ];
    }

    private function formatGroupLabel(?string $groupKey): ?string
    {
        if ($groupKey === null) {
            return null;
        }

        if ($groupKey === 'final') {
            return 'Final RR';
        }

        return TournamentGroup::label($groupKey);
    }
}
