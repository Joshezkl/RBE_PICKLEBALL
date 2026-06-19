<?php

namespace App\Services;

use App\Models\Tournament;
use App\Models\TournamentCategory;
use App\Models\TournamentMatch;
use App\Models\TournamentTeam;
use App\Support\TournamentGroup;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class TournamentScheduleService
{
    public function __construct(
        private TournamentStandingsService $standingsService,
    ) {}

    public function assignGroupsRandomly(TournamentCategory $category, Tournament $tournament): void
    {
        $groupKeys = TournamentGroup::keysForCount((int) $tournament->group_count);
        $teams = $category->teams()->get()->shuffle()->values();

        foreach ($teams as $index => $team) {
            $team->update([
                'group_key' => $groupKeys[$index % count($groupKeys)],
            ]);
        }
    }

    public function generateRoundRobin(TournamentCategory $category): void
    {
        $category->load('tournament');
        $tournament = $category->tournament;
        $groupKeys = TournamentGroup::keysForCount((int) $tournament->group_count);
        $teams = $category->teams()->orderBy('id')->get();

        foreach ($groupKeys as $groupKey) {
            $groupTeams = $teams->where('group_key', $groupKey);
            if ($groupTeams->count() < 2) {
                throw new \InvalidArgumentException(
                    TournamentGroup::label($groupKey).' needs at least two teams before starting'
                );
            }
        }

        $unassigned = $teams->whereNull('group_key')->count();
        if ($unassigned > 0) {
            throw new \InvalidArgumentException('Teams must be assigned to groups before starting');
        }

        DB::transaction(function () use ($category, $teams, $groupKeys) {
            TournamentMatch::query()
                ->where('tournament_category_id', $category->id)
                ->delete();

            foreach ($teams as $team) {
                $team->update([
                    'wins' => 0,
                    'losses' => 0,
                    'points_scored' => 0,
                    'points_allowed' => 0,
                    'seed' => null,
                    'status' => 'active',
                ]);
            }

            $scheduledMatches = [];

            foreach ($groupKeys as $groupKey) {
                $groupTeams = $teams->where('group_key', $groupKey)->values();
                foreach ($this->buildRoundRobinPairings($groupTeams) as $pairing) {
                    $scheduledMatches[] = [
                        'group_key' => $groupKey,
                        'team_a_id' => $pairing['teamA']->id,
                        'team_b_id' => $pairing['teamB']->id,
                        'round_index' => $pairing['round'],
                    ];
                }
            }

            $scheduledMatches = collect($scheduledMatches)
                ->sortBy([
                    ['round_index', 'asc'],
                    ['group_key', 'asc'],
                ])
                ->values();

            foreach ($scheduledMatches as $matchIndex => $scheduledMatch) {
                TournamentMatch::query()->create([
                    'tournament_id' => $category->tournament_id,
                    'tournament_category_id' => $category->id,
                    'group_key' => $scheduledMatch['group_key'],
                    'phase' => 'round_robin',
                    'round_index' => $scheduledMatch['round_index'],
                    'match_index' => $matchIndex,
                    'team_a_id' => $scheduledMatch['team_a_id'],
                    'team_b_id' => $scheduledMatch['team_b_id'],
                    'status' => 'scheduled',
                ]);
            }

            $category->update(['phase' => 'round_robin']);
        });
    }

    public function integrateLateRoundRobinTeam(
        TournamentCategory $category,
        TournamentTeam $team,
    ): void {
        if ($category->phase !== 'round_robin') {
            throw new \RuntimeException('Late registration is only available during round robin');
        }

        $tournament = $category->tournament()->firstOrFail();
        $groupKey = $this->pickGroupForLateTeam($category, $tournament);

        $team->update([
            'group_key' => $groupKey,
            'status' => 'active',
            'wins' => 0,
            'losses' => 0,
            'points_scored' => 0,
            'points_allowed' => 0,
        ]);

        $opponents = $category->teams()
            ->where('group_key', $groupKey)
            ->where('id', '!=', $team->id)
            ->orderBy('id')
            ->get();

        $maxMatchIndex = (int) (TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->max('match_index') ?? -1);

        $maxRoundIndex = (int) (TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->max('round_index') ?? 0);

        foreach ($opponents as $opponent) {
            if ($this->pairingExists($category, $team->id, $opponent->id)) {
                continue;
            }

            $maxMatchIndex++;
            TournamentMatch::query()->create([
                'tournament_id' => $category->tournament_id,
                'tournament_category_id' => $category->id,
                'group_key' => $groupKey,
                'phase' => 'round_robin',
                'round_index' => $maxRoundIndex,
                'match_index' => $maxMatchIndex,
                'team_a_id' => $team->id,
                'team_b_id' => $opponent->id,
                'status' => 'scheduled',
            ]);
        }
    }

    public function withdrawRoundRobinTeam(
        TournamentCategory $category,
        TournamentTeam $team,
    ): void {
        if ($category->phase !== 'round_robin') {
            throw new \RuntimeException('Cannot withdraw teams after round robin has finished');
        }

        DB::transaction(function () use ($category, $team) {
            TournamentMatch::query()
                ->where('tournament_category_id', $category->id)
                ->whereIn('status', ['scheduled', 'on_court'])
                ->where(function ($query) use ($team) {
                    $query->where('team_a_id', $team->id)
                        ->orWhere('team_b_id', $team->id);
                })
                ->delete();
        });
    }

    private function pickGroupForLateTeam(
        TournamentCategory $category,
        Tournament $tournament,
    ): string {
        $groupKeys = TournamentGroup::keysForCount((int) $tournament->group_count);
        $counts = [];

        foreach ($groupKeys as $groupKey) {
            $counts[$groupKey] = $category->teams()
                ->where('group_key', $groupKey)
                ->count();
        }

        asort($counts);

        return (string) array_key_first($counts);
    }

    private function pairingExists(
        TournamentCategory $category,
        int $teamAId,
        int $teamBId,
    ): bool {
        return TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'round_robin')
            ->where(function ($query) use ($teamAId, $teamBId) {
                $query
                    ->where(function ($pair) use ($teamAId, $teamBId) {
                        $pair->where('team_a_id', $teamAId)
                            ->where('team_b_id', $teamBId);
                    })
                    ->orWhere(function ($pair) use ($teamAId, $teamBId) {
                        $pair->where('team_a_id', $teamBId)
                            ->where('team_b_id', $teamAId);
                    });
            })
            ->exists();
    }

    /**
     * @param  Collection<int, TournamentTeam>  $groupTeams
     * @return list<array{teamA: TournamentTeam, teamB: TournamentTeam, round: int}>
     */
    private function buildRoundRobinPairings(Collection $groupTeams): array
    {
        $teams = $groupTeams->values()->all();
        $count = count($teams);

        if ($count < 2) {
            return [];
        }

        if ($count % 2 === 1) {
            $teams[] = null;
            $count++;
        }

        $rounds = $count - 1;
        $half = (int) ($count / 2);
        $pairings = [];

        for ($round = 0; $round < $rounds; $round++) {
            for ($i = 0; $i < $half; $i++) {
                $home = $teams[$i];
                $away = $teams[$count - 1 - $i];

                if ($home === null || $away === null) {
                    continue;
                }

                $pairings[] = [
                    'teamA' => $home,
                    'teamB' => $away,
                    'round' => $round,
                ];
            }

            if ($count <= 2) {
                break;
            }

            $rotated = array_pop($teams);
            array_splice($teams, 1, 0, [$rotated]);
        }

        return $pairings;
    }

    public function roundRobinComplete(TournamentCategory $category): bool
    {
        $pending = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'round_robin')
            ->where('status', '!=', 'finished')
            ->count();

        return $pending === 0
            && TournamentMatch::query()
                ->where('tournament_category_id', $category->id)
                ->where('phase', 'round_robin')
                ->exists();
    }

    public function advanceToSingleElimination(TournamentCategory $category, Tournament $tournament): void
    {
        if (! $this->roundRobinComplete($category)) {
            throw new \RuntimeException('Round robin is not complete');
        }

        $groupKeys = TournamentGroup::keysForCount((int) $tournament->group_count);
        $advancers = collect();

        foreach ($groupKeys as $groupKey) {
            $groupLeader = $this->standingsService
                ->rankedTeamsInGroup($category, $groupKey)
                ->first();

            if ($groupLeader === null) {
                throw new \RuntimeException(
                    TournamentGroup::label($groupKey).' has no teams to advance'
                );
            }

            $advancers->push($groupLeader);
        }

        if (count($groupKeys) === 1) {
            $activeTeams = $category->teams()->where('status', 'active')->get();
            if ($activeTeams->count() === 3) {
                $this->startFinalRoundRobin($category, $activeTeams);

                return;
            }
        }

        if ($advancers->count() < 2) {
            $champion = $advancers->first();
            if ($champion) {
                $champion->update(['status' => 'champion', 'seed' => 1]);

                $runnerUpId = null;
                if (count($groupKeys) === 1) {
                    $runnerUp = $this->standingsService
                        ->rankedTeamsInGroup($category, $groupKeys[0])
                        ->skip(1)
                        ->first();
                    if ($runnerUp) {
                        $runnerUp->update(['status' => 'runner_up']);
                        $runnerUpId = $runnerUp->id;
                    }
                }

                $category->teams()
                    ->where('id', '!=', $champion->id)
                    ->when($runnerUpId !== null, fn ($query) => $query->where('id', '!=', $runnerUpId))
                    ->update(['status' => 'eliminated']);
            }
            $category->update(['phase' => 'completed']);

            return;
        }

        if ($advancers->count() === 3) {
            $this->startFinalRoundRobin($category, $advancers);

            return;
        }

        DB::transaction(function () use ($category, $advancers) {
            foreach ($advancers as $index => $team) {
                $team->update(['seed' => $index + 1, 'status' => 'active']);
            }

            $category->teams()
                ->whereNotIn('id', $advancers->pluck('id'))
                ->update(['status' => 'eliminated']);

            $this->generateSingleEliminationBracket($category, $advancers);
            $category->update(['phase' => 'single_elimination']);
        });
    }

    /**
     * @param  Collection<int, TournamentTeam>  $teams
     */
    private function startFinalRoundRobin(
        TournamentCategory $category,
        Collection $teams,
    ): void {
        DB::transaction(function () use ($category, $teams) {
            foreach ($teams->values() as $index => $team) {
                $team->update([
                    'seed' => $index + 1,
                    'status' => 'active',
                    'wins' => 0,
                    'losses' => 0,
                    'points_scored' => 0,
                    'points_allowed' => 0,
                ]);
            }

            $category->teams()
                ->whereNotIn('id', $teams->pluck('id'))
                ->update(['status' => 'eliminated']);

            $this->generateFinalRoundRobin($category, $teams);
            $category->update(['phase' => 'final_round_robin']);
        });
    }

    /**
     * Converts legacy 3-team bye brackets (Mac vs TBD) into a final round robin.
     */
    public function repairThreeTeamPlayoffFormat(TournamentCategory $category): void
    {
        if ($category->phase !== 'single_elimination') {
            return;
        }

        if (TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'final_round_robin')
            ->exists()) {
            return;
        }

        $activeTeams = $category->teams()->where('status', 'active')->get();
        if ($activeTeams->count() !== 3) {
            return;
        }

        $elimMatches = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'single_elimination')
            ->get();

        if ($elimMatches->isEmpty()) {
            return;
        }

        $roundZero = $elimMatches->where('round_index', 0);
        $hasBye = $roundZero->contains(
            fn (TournamentMatch $match) => ($match->team_a_id && ! $match->team_b_id)
                || (! $match->team_a_id && $match->team_b_id)
        );

        if (! $hasBye) {
            return;
        }

        if ($elimMatches->contains(
            fn (TournamentMatch $match) => $match->status === 'finished'
                && $match->team_a_id && $match->team_b_id
        )) {
            return;
        }

        TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->whereIn('phase', ['single_elimination', 'third_place'])
            ->delete();

        $this->startFinalRoundRobin($category, $activeTeams);
    }

    /**
     * @param  Collection<int, TournamentTeam>  $advancers
     */
    private function generateFinalRoundRobin(
        TournamentCategory $category,
        Collection $advancers,
    ): void {
        $pairings = $this->buildRoundRobinPairings($advancers->values());

        foreach ($pairings as $matchIndex => $pairing) {
            TournamentMatch::query()->create([
                'tournament_id' => $category->tournament_id,
                'tournament_category_id' => $category->id,
                'group_key' => 'final',
                'phase' => 'final_round_robin',
                'round_index' => $pairing['round'],
                'match_index' => $matchIndex,
                'team_a_id' => $pairing['teamA']->id,
                'team_b_id' => $pairing['teamB']->id,
                'status' => 'scheduled',
            ]);
        }
    }

    public function finalRoundRobinComplete(TournamentCategory $category): bool
    {
        $pending = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'final_round_robin')
            ->where('status', '!=', 'finished')
            ->count();

        return $pending === 0
            && TournamentMatch::query()
                ->where('tournament_category_id', $category->id)
                ->where('phase', 'final_round_robin')
                ->exists();
    }

    public function finalizeFinalRoundRobin(TournamentCategory $category): void
    {
        if (! $this->finalRoundRobinComplete($category)) {
            return;
        }

        $tiebreaker = $this->finalTiebreakerMatch($category);
        if ($tiebreaker !== null && $tiebreaker->status !== 'finished') {
            return;
        }

        $ranked = $this->standingsService->rankedFinalRoundRobinTeams($category);

        if ($tiebreaker === null) {
            $pair = $this->standingsService->detectFinalRoundRobinTiebreakerPair($category, $ranked);
            if ($pair !== null) {
                $this->createFinalTiebreakerMatch($category, $pair[0], $pair[1]);

                return;
            }
        } elseif ($tiebreaker->winner_team_id) {
            $ranked = $this->standingsService->rankedFinalRoundRobinTeams($category);
        }

        $this->applyFinalRoundRobinPlacements($category, $ranked);
        $category->update(['phase' => 'completed']);
    }

    /**
     * @param  Collection<int, TournamentTeam>  $ranked
     */
    private function applyFinalRoundRobinPlacements(
        TournamentCategory $category,
        Collection $ranked,
    ): void {
        $statuses = ['champion', 'runner_up', 'third'];

        foreach ($ranked->values() as $index => $team) {
            if ($index > 2) {
                break;
            }

            $team->update(['status' => $statuses[$index]]);
        }

        $placedIds = $ranked->take(3)->pluck('id')->all();

        TournamentTeam::query()
            ->where('tournament_category_id', $category->id)
            ->whereNotIn('id', $placedIds)
            ->update(['status' => 'eliminated']);
    }

    private function createFinalTiebreakerMatch(
        TournamentCategory $category,
        TournamentTeam $teamA,
        TournamentTeam $teamB,
    ): void {
        if ($this->finalTiebreakerMatch($category) !== null) {
            return;
        }

        TournamentMatch::query()->create([
            'tournament_id' => $category->tournament_id,
            'tournament_category_id' => $category->id,
            'group_key' => 'final',
            'phase' => 'tiebreaker',
            'round_index' => 0,
            'match_index' => 0,
            'team_a_id' => $teamA->id,
            'team_b_id' => $teamB->id,
            'status' => 'scheduled',
        ]);
    }

    private function finalTiebreakerMatch(TournamentCategory $category): ?TournamentMatch
    {
        return TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'tiebreaker')
            ->first();
    }

    /**
     * @param  Collection<int, TournamentTeam>  $advancers
     */
    private function generateSingleEliminationBracket(
        TournamentCategory $category,
        Collection $advancers,
    ): void {
        $seeds = $advancers->values();
        $teamCount = $seeds->count();
        $bracketSize = 2 ** (int) ceil(log(max($teamCount, 2), 2));
        $roundCount = (int) log($bracketSize, 2);
        $matchesByRound = [];

        for ($round = $roundCount - 1; $round >= 0; $round--) {
            $matchesInRound = 2 ** ($roundCount - 1 - $round);
            $roundMatches = [];

            for ($matchIndex = 0; $matchIndex < $matchesInRound; $matchIndex++) {
                $teamAId = null;
                $teamBId = null;

                if ($round === 0) {
                    [$seedA, $seedB] = $this->bracketSeedPair($bracketSize, $matchIndex);
                    if ($seedA < $teamCount) {
                        $teamAId = $seeds[$seedA]->id;
                    }
                    if ($seedB < $teamCount) {
                        $teamBId = $seeds[$seedB]->id;
                    }
                }

                $match = TournamentMatch::query()->create([
                    'tournament_id' => $category->tournament_id,
                    'tournament_category_id' => $category->id,
                    'phase' => 'single_elimination',
                    'round_index' => $round,
                    'match_index' => $matchIndex,
                    'team_a_id' => $teamAId,
                    'team_b_id' => $teamBId,
                    'status' => 'scheduled',
                ]);

                if ($round === 0 && $teamAId !== null && $teamBId === null) {
                    $match->update([
                        'winner_team_id' => $teamAId,
                        'status' => 'finished',
                    ]);
                    if ($round < $roundCount - 1) {
                        $this->placeByeWinner($match, $matchesByRound, $round, $matchIndex, $teamAId);
                    }
                } elseif ($round === 0 && $teamBId !== null && $teamAId === null) {
                    $match->update([
                        'winner_team_id' => $teamBId,
                        'status' => 'finished',
                    ]);
                    if ($round < $roundCount - 1) {
                        $this->placeByeWinner($match, $matchesByRound, $round, $matchIndex, $teamBId);
                    }
                }

                if ($round < $roundCount - 1 && isset($matchesByRound[$round + 1])) {
                    $nextRound = $matchesByRound[$round + 1];
                    $feedsInto = $nextRound[intdiv($matchIndex, 2)];
                    $feedSlot = $matchIndex % 2 === 0 ? 'team_a' : 'team_b';

                    $match->update([
                        'feeds_into_match_id' => $feedsInto->id,
                        'feed_slot' => $feedSlot,
                    ]);

                    if ($match->status === 'finished' && $match->winner_team_id) {
                        $field = $feedSlot === 'team_b' ? 'team_b_id' : 'team_a_id';
                        $feedsInto->update([$field => $match->winner_team_id]);
                    }
                }

                $roundMatches[] = $match->fresh();
            }

            $matchesByRound[$round] = $roundMatches;
        }
    }

    /**
     * @return array{0: int, 1: int}
     */
    private function bracketSeedPair(int $bracketSize, int $matchIndex): array
    {
        $pairs = [];
        for ($i = 0; $i < $bracketSize / 2; $i++) {
            $pairs[] = [$i, $bracketSize - 1 - $i];
        }

        return $pairs[$matchIndex];
    }

    /**
     * @param  array<int, list<TournamentMatch>>  $matchesByRound
     */
    private function placeByeWinner(
        TournamentMatch $byeMatch,
        array $matchesByRound,
        int $round,
        int $matchIndex,
        int $winnerTeamId,
    ): void {
        if (! isset($matchesByRound[$round + 1])) {
            return;
        }

        $feedsInto = $matchesByRound[$round + 1][intdiv($matchIndex, 2)];
        $feedSlot = $matchIndex % 2 === 0 ? 'team_a' : 'team_b';
        $field = $feedSlot === 'team_b' ? 'team_b_id' : 'team_a_id';
        $feedsInto->update([$field => $winnerTeamId]);

        $byeMatch->update([
            'feeds_into_match_id' => $feedsInto->id,
            'feed_slot' => $feedSlot,
        ]);
    }

    public function singleEliminationComplete(TournamentCategory $category): bool
    {
        return $this->playoffsComplete($category);
    }

    public function playoffsComplete(TournamentCategory $category): bool
    {
        $this->maybeCreateThirdPlaceMatch($category);

        $final = $this->finalMatch($category);
        if ($final === null || $final->status !== 'finished') {
            return false;
        }

        $thirdPlace = $this->thirdPlaceMatch($category);
        if ($thirdPlace !== null) {
            return $thirdPlace->status === 'finished';
        }

        return true;
    }

    public function maybeCreateThirdPlaceMatch(TournamentCategory $category): void
    {
        if ($this->thirdPlaceMatch($category) !== null) {
            return;
        }

        $semiMatches = $this->semifinalMatches($category);
        if ($semiMatches === null) {
            return;
        }

        if ($semiMatches->contains(fn (TournamentMatch $match) => $match->status !== 'finished')) {
            return;
        }

        $losers = $semiMatches
            ->map(fn (TournamentMatch $match) => $this->loserTeamId($match))
            ->filter()
            ->values();

        if ($losers->count() !== 2) {
            return;
        }

        TournamentMatch::query()->create([
            'tournament_id' => $category->tournament_id,
            'tournament_category_id' => $category->id,
            'phase' => 'third_place',
            'round_index' => 0,
            'match_index' => 0,
            'team_a_id' => $losers[0],
            'team_b_id' => $losers[1],
            'status' => 'scheduled',
        ]);
    }

    public function ensureThirdPlaceMatchForScoring(TournamentCategory $category): void
    {
        $this->maybeCreateThirdPlaceMatch($category);

        $thirdPlace = $this->thirdPlaceMatch($category);
        if ($thirdPlace === null || $thirdPlace->status === 'finished') {
            return;
        }

        if ($category->phase !== 'completed') {
            return;
        }

        $category->teams()->where('status', 'third')->update(['status' => 'eliminated']);
        $category->update(['phase' => 'single_elimination']);

        $tournament = $category->tournament()->first();
        if ($tournament !== null) {
            $tournament->update([
                'status' => 'single_elimination',
                'ended_at' => null,
            ]);
        }
    }

    public function finalizeCategory(TournamentCategory $category): void
    {
        $final = $this->finalMatch($category);
        $thirdPlace = $this->thirdPlaceMatch($category);

        if ($final?->winner_team_id) {
            $championId = $final->winner_team_id;
            $runnerUpId = $this->loserTeamId($final);
            $thirdId = $thirdPlace?->winner_team_id;

            TournamentTeam::query()
                ->where('tournament_category_id', $category->id)
                ->where('id', $championId)
                ->update(['status' => 'champion']);

            if ($runnerUpId) {
                TournamentTeam::query()
                    ->where('tournament_category_id', $category->id)
                    ->where('id', $runnerUpId)
                    ->update(['status' => 'runner_up']);
            }

            if ($thirdId) {
                TournamentTeam::query()
                    ->where('tournament_category_id', $category->id)
                    ->where('id', $thirdId)
                    ->update(['status' => 'third']);
            }

            $placedIds = array_filter([$championId, $runnerUpId, $thirdId]);

            TournamentTeam::query()
                ->where('tournament_category_id', $category->id)
                ->whereNotIn('id', $placedIds)
                ->whereIn('status', ['active', 'eliminated'])
                ->update(['status' => 'eliminated']);
        }

        $category->update(['phase' => 'completed']);
    }

    /**
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    public function buildPlacementsPayload(TournamentCategory $category): array
    {
        if ($category->phase !== 'completed') {
            return [];
        }

        $this->backfillPlacementsIfNeeded($category);
        $category->refresh();

        return $this->placementsFromTeamStatuses($category);
    }

    public function backfillPlacementsIfNeeded(TournamentCategory $category): void
    {
        if ($category->phase !== 'completed') {
            return;
        }

        $derived = $this->derivePlacements($category);
        if ($derived === []) {
            return;
        }

        $current = $this->placementsFromTeamStatuses($category);
        if ($this->placementsMatch($current, $derived)) {
            return;
        }

        $this->applyPlacements($category, $derived);
    }

    /**
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    private function derivePlacements(TournamentCategory $category): array
    {
        $final = $this->finalMatch($category);
        if ($final !== null && $final->status === 'finished' && $final->winner_team_id) {
            return $this->derivePlayoffPlacements($category, $final);
        }

        if ($this->hasFinalRoundRobin($category)) {
            return $this->deriveFinalRoundRobinPlacements($category);
        }

        return $this->deriveRoundRobinPlacements($category);
    }

    private function hasFinalRoundRobin(TournamentCategory $category): bool
    {
        return TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'final_round_robin')
            ->exists();
    }

    /**
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    private function deriveFinalRoundRobinPlacements(TournamentCategory $category): array
    {
        $entries = [];

        foreach ([1 => 'champion', 2 => 'runner_up', 3 => 'third'] as $place => $status) {
            $team = $category->teams()->where('status', $status)->first();
            if ($team) {
                $entries[] = ['place' => $place, 'team' => $team];
            }
        }

        return $this->formatPlacementEntries($entries);
    }

    /**
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    private function derivePlayoffPlacements(
        TournamentCategory $category,
        TournamentMatch $final,
    ): array {
        $entries = [];

        $champion = $category->teams()->find($final->winner_team_id);
        if ($champion) {
            $entries[] = ['place' => 1, 'team' => $champion];
        }

        $runnerUpId = $this->loserTeamId($final);
        if ($runnerUpId) {
            $runnerUp = $category->teams()->find($runnerUpId);
            if ($runnerUp) {
                $entries[] = ['place' => 2, 'team' => $runnerUp];
            }
        }

        $thirdPlace = $this->thirdPlaceMatch($category);
        if ($thirdPlace?->status === 'finished' && $thirdPlace->winner_team_id) {
            $third = $category->teams()->find($thirdPlace->winner_team_id);
            if ($third) {
                $entries[] = ['place' => 3, 'team' => $third];
            }
        } else {
            $third = $this->resolveThirdPlaceByTiebreaker($category);
            if ($third) {
                $entries[] = ['place' => 3, 'team' => $third];
            }
        }

        return $this->formatPlacementEntries($entries);
    }

    /**
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    private function deriveRoundRobinPlacements(TournamentCategory $category): array
    {
        $category->loadMissing('tournament');
        $entries = [];

        $champion = $category->teams()->where('status', 'champion')->first();
        if ($champion) {
            $entries[] = ['place' => 1, 'team' => $champion];
        }

        $runnerUp = $category->teams()->where('status', 'runner_up')->first();
        if ($runnerUp === null && $category->tournament !== null) {
            $groupKeys = TournamentGroup::keysForCount((int) $category->tournament->group_count);
            if (count($groupKeys) === 1) {
                $runnerUp = $this->standingsService
                    ->rankedTeamsInGroup($category, $groupKeys[0])
                    ->skip(1)
                    ->first();
            }
        }

        if ($runnerUp) {
            $entries[] = ['place' => 2, 'team' => $runnerUp];
        }

        return $this->formatPlacementEntries($entries);
    }

    private function resolveThirdPlaceByTiebreaker(TournamentCategory $category): ?TournamentTeam
    {
        $semiMatches = $this->semifinalMatches($category);
        if ($semiMatches === null) {
            return null;
        }

        if ($semiMatches->contains(fn (TournamentMatch $match) => $match->status !== 'finished')) {
            return null;
        }

        $loserIds = $semiMatches
            ->map(fn (TournamentMatch $match) => $this->loserTeamId($match))
            ->filter()
            ->values();

        if ($loserIds->count() !== 2) {
            return null;
        }

        return $category->teams()
            ->whereIn('id', $loserIds->all())
            ->get()
            ->sortByDesc(fn (TournamentTeam $team) => [
                $team->wins,
                $team->pointDifferential(),
                -$team->losses,
            ])
            ->values()
            ->first();
    }

    /**
     * @param  list<array{place: int, team: TournamentTeam}>  $entries
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    private function formatPlacementEntries(array $entries): array
    {
        return collect($entries)
            ->sortBy('place')
            ->map(fn (array $entry) => [
                'place' => $entry['place'],
                'teamId' => $entry['team']->id,
                'displayName' => $entry['team']->display_name,
            ])
            ->values()
            ->all();
    }

    /**
     * @return list<array{place: int, teamId: int, displayName: string}>
     */
    private function placementsFromTeamStatuses(TournamentCategory $category): array
    {
        $placements = [];

        foreach ([1 => 'champion', 2 => 'runner_up', 3 => 'third'] as $place => $status) {
            $team = $category->teams()->where('status', $status)->first();
            if ($team) {
                $placements[] = [
                    'place' => $place,
                    'teamId' => $team->id,
                    'displayName' => $team->display_name,
                ];
            }
        }

        return $placements;
    }

    /**
     * @param  list<array{place: int, teamId: int, displayName: string}>  $left
     * @param  list<array{place: int, teamId: int, displayName: string}>  $right
     */
    private function placementsMatch(array $left, array $right): bool
    {
        if (count($left) !== count($right)) {
            return false;
        }

        foreach ($left as $index => $placement) {
            if ($placement['place'] !== $right[$index]['place']
                || $placement['teamId'] !== $right[$index]['teamId']) {
                return false;
            }
        }

        return true;
    }

    /**
     * @param  list<array{place: int, teamId: int, displayName: string}>  $placements
     */
    private function applyPlacements(TournamentCategory $category, array $placements): void
    {
        $placedIds = [];

        foreach ($placements as $placement) {
            $status = match ($placement['place']) {
                1 => 'champion',
                2 => 'runner_up',
                3 => 'third',
                default => null,
            };

            if ($status === null) {
                continue;
            }

            TournamentTeam::query()
                ->where('tournament_category_id', $category->id)
                ->where('id', $placement['teamId'])
                ->update(['status' => $status]);

            $placedIds[] = $placement['teamId'];
        }

        if ($placedIds !== []) {
            TournamentTeam::query()
                ->where('tournament_category_id', $category->id)
                ->whereNotIn('id', $placedIds)
                ->whereIn('status', ['active', 'champion', 'runner_up', 'third'])
                ->update(['status' => 'eliminated']);
        }
    }

    private function finalMatch(TournamentCategory $category): ?TournamentMatch
    {
        $maxRound = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'single_elimination')
            ->max('round_index');

        if ($maxRound === null) {
            return null;
        }

        return TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'single_elimination')
            ->where('round_index', $maxRound)
            ->first();
    }

    private function thirdPlaceMatch(TournamentCategory $category): ?TournamentMatch
    {
        return TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'third_place')
            ->first();
    }

    /**
     * @return Collection<int, TournamentMatch>|null
     */
    private function semifinalMatches(TournamentCategory $category): ?Collection
    {
        $maxRound = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'single_elimination')
            ->max('round_index');

        if ($maxRound === null || $maxRound < 1) {
            return null;
        }

        $semiRound = $maxRound - 1;
        $semiMatches = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'single_elimination')
            ->where('round_index', $semiRound)
            ->orderBy('match_index')
            ->get();

        return $semiMatches->count() === 2 ? $semiMatches : null;
    }

    private function loserTeamId(TournamentMatch $match): ?int
    {
        if ($match->winner_team_id === null) {
            return null;
        }

        if ($match->winner_team_id === $match->team_a_id) {
            return $match->team_b_id;
        }

        return $match->team_a_id;
    }

    public function roundLabel(int $roundIndex, int $maxRoundIndex): string
    {
        $roundsFromFinal = $maxRoundIndex - $roundIndex;

        return match ($roundsFromFinal) {
            0 => 'Final',
            1 => 'Semifinals',
            2 => 'Quarterfinals',
            default => 'Round '.($roundIndex + 1),
        };
    }
}
