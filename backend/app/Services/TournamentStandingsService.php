<?php

namespace App\Services;

use App\Models\TournamentCategory;
use App\Models\TournamentMatch;
use App\Models\TournamentTeam;
use App\Support\TournamentGroup;
use Illuminate\Support\Collection;

class TournamentStandingsService
{
    /**
     * @return Collection<int, TournamentTeam>
     */
    public function rankedTeams(TournamentCategory $category): Collection
    {
        return $this->rankedTeamsInGroup($category, null);
    }

    /**
     * @return Collection<int, TournamentTeam>
     */
    public function rankedTeamsInGroup(TournamentCategory $category, ?string $groupKey): Collection
    {
        $query = $category->teams()->orderByDesc('wins')->orderByDesc('points_scored');

        if ($groupKey !== null) {
            $query->where('group_key', $groupKey);
        }

        $teams = $query->get();

        return $this->applyTiebreakers($category, $teams, $groupKey);
    }

    /**
     * @return list<array{key: string, label: string, standings: list<array<string, mixed>>}>
     */
    public function groupStandingsPayload(TournamentCategory $category, int $groupCount): array
    {
        return collect(TournamentGroup::keysForCount($groupCount))
            ->map(function (string $groupKey) use ($category) {
                return [
                    'key' => $groupKey,
                    'label' => TournamentGroup::label($groupKey),
                    'standings' => $this->standingsPayloadForGroup($category, $groupKey),
                ];
            })
            ->all();
    }

    /**
     * @return list<array{teamId: int, displayName: string, wins: int, losses: int, pointsScored: int, pointsAllowed: int, pointDifferential: int, rank: int, groupKey: string|null, status: string}>
     */
    public function standingsPayload(TournamentCategory $category): array
    {
        return $this->standingsPayloadForGroup($category, null);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function standingsPayloadForGroup(TournamentCategory $category, ?string $groupKey): array
    {
        $ranked = $this->rankedTeamsInGroup($category, $groupKey);

        return $ranked->values()->map(function (TournamentTeam $team, int $index) {
            return [
                'teamId' => $team->id,
                'displayName' => $team->display_name,
                'wins' => $team->wins,
                'losses' => $team->losses,
                'pointsScored' => $team->points_scored,
                'pointsAllowed' => $team->points_allowed,
                'pointDifferential' => $team->pointDifferential(),
                'rank' => $index + 1,
                'groupKey' => $team->group_key,
                'status' => $team->status,
            ];
        })->all();
    }

    /**
     * @return Collection<int, TournamentTeam>
     */
    public function rankedFinalRoundRobinTeams(TournamentCategory $category): Collection
    {
        $teamIds = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->where('phase', 'final_round_robin')
            ->get()
            ->flatMap(fn (TournamentMatch $match) => [$match->team_a_id, $match->team_b_id])
            ->filter()
            ->unique()
            ->values();

        $teams = $category->teams()
            ->whereIn('id', $teamIds)
            ->orderByDesc('wins')
            ->orderByDesc('points_scored')
            ->get();

        return $this->applyFinalRoundRobinTiebreakers($category, $teams);
    }

    /**
     * @return list<array{teamId: int, displayName: string, wins: int, losses: int, pointsScored: int, pointsAllowed: int, pointDifferential: int, rank: int, groupKey: string|null, status: string}>
     */
    public function finalRoundRobinStandingsPayload(TournamentCategory $category): array
    {
        return $this->rankedFinalRoundRobinTeams($category)
            ->values()
            ->map(function (TournamentTeam $team, int $index) {
                return [
                    'teamId' => $team->id,
                    'displayName' => $team->display_name,
                    'wins' => $team->wins,
                    'losses' => $team->losses,
                    'pointsScored' => $team->points_scored,
                    'pointsAllowed' => $team->points_allowed,
                    'pointDifferential' => $team->pointDifferential(),
                    'rank' => $index + 1,
                    'groupKey' => $team->group_key,
                    'status' => $team->status,
                ];
            })
            ->all();
    }

    /**
     * @param  Collection<int, TournamentTeam>  $ranked
     * @return array{0: TournamentTeam, 1: TournamentTeam}|null
     */
    public function detectFinalRoundRobinTiebreakerPair(
        TournamentCategory $category,
        Collection $ranked,
    ): ?array {
        $teams = $ranked->values();

        for ($index = 0; $index < $teams->count() - 1; $index++) {
            $teamA = $teams[$index];
            $teamB = $teams[$index + 1];

            if ($this->teamsFullyTiedForFinalRanking($category, $teamA, $teamB)) {
                return [$teamA, $teamB];
            }
        }

        return null;
    }

    private function teamsFullyTiedForFinalRanking(
        TournamentCategory $category,
        TournamentTeam $teamA,
        TournamentTeam $teamB,
    ): bool {
        if ($teamA->wins !== $teamB->wins
            || $teamA->pointDifferential() !== $teamB->pointDifferential()
            || $teamA->points_scored !== $teamB->points_scored) {
            return false;
        }

        return $this->headToHeadWinner(
            $category,
            $teamA,
            $teamB,
            null,
            ['final_round_robin', 'tiebreaker'],
        ) === null;
    }

    /**
     * @param  Collection<int, TournamentTeam>  $teams
     * @return Collection<int, TournamentTeam>
     */
    private function applyFinalRoundRobinTiebreakers(
        TournamentCategory $category,
        Collection $teams,
    ): Collection {
        if ($teams->count() <= 1) {
            return $teams->values();
        }

        $groups = $teams->groupBy(fn (TournamentTeam $team) => (string) $team->wins);
        $ranked = collect();

        foreach ($groups->sortKeysDesc() as $group) {
            $ranked = $ranked->concat(
                $this->resolveFinalRoundRobinTiedGroup($category, $group->values())
            );
        }

        return $ranked->values();
    }

    /**
     * @param  Collection<int, TournamentTeam>  $tied
     * @return Collection<int, TournamentTeam>
     */
    private function resolveFinalRoundRobinTiedGroup(
        TournamentCategory $category,
        Collection $tied,
    ): Collection {
        if ($tied->count() <= 1) {
            return $tied;
        }

        $pointDiffGroups = $tied->groupBy(fn (TournamentTeam $team) => $team->pointDifferential());
        $resolved = collect();

        foreach ($pointDiffGroups->sortKeysDesc() as $pointGroup) {
            if ($pointGroup->count() === 1) {
                $resolved->push($pointGroup->first());

                continue;
            }

            $resolved = $resolved->concat(
                $this->resolveFinalRoundRobinByHeadToHead($category, $pointGroup->values())
            );
        }

        return $resolved;
    }

    /**
     * @param  Collection<int, TournamentTeam>  $tied
     * @return Collection<int, TournamentTeam>
     */
    private function resolveFinalRoundRobinByHeadToHead(
        TournamentCategory $category,
        Collection $tied,
    ): Collection {
        if ($tied->count() === 2) {
            $winner = $this->headToHeadWinner(
                $category,
                $tied[0],
                $tied[1],
                null,
                ['final_round_robin', 'tiebreaker'],
            );

            if ($winner !== null) {
                $loser = $winner->id === $tied[0]->id ? $tied[1] : $tied[0];

                return collect([$winner, $loser]);
            }
        }

        $records = $tied->mapWithKeys(function (TournamentTeam $team) use ($category, $tied) {
            $wins = 0;
            foreach ($tied as $opponent) {
                if ($opponent->id === $team->id) {
                    continue;
                }

                $winner = $this->headToHeadWinner(
                    $category,
                    $team,
                    $opponent,
                    null,
                    ['final_round_robin', 'tiebreaker'],
                );
                if ($winner?->id === $team->id) {
                    $wins++;
                }
            }

            return [$team->id => $wins];
        });

        $headToHeadGroups = $tied->groupBy(fn (TournamentTeam $team) => (string) $records[$team->id]);
        $resolved = collect();

        foreach ($headToHeadGroups->sortKeysDesc() as $headToHeadGroup) {
            if ($headToHeadGroup->count() === 1) {
                $resolved->push($headToHeadGroup->first());

                continue;
            }

            $pointsGroups = $headToHeadGroup->groupBy(fn (TournamentTeam $team) => $team->points_scored);
            foreach ($pointsGroups->sortKeysDesc() as $pointsGroup) {
                $resolved = $resolved->concat($pointsGroup->values());
            }
        }

        return $resolved->values();
    }

    /**
     * @param  Collection<int, TournamentTeam>  $teams
     * @return Collection<int, TournamentTeam>
     */
    private function applyTiebreakers(
        TournamentCategory $category,
        Collection $teams,
        ?string $groupKey,
    ): Collection {
        if ($teams->count() <= 1) {
            return $teams->values();
        }

        $groups = $teams->groupBy(fn (TournamentTeam $team) => (string) $team->wins);
        $ranked = collect();

        foreach ($groups->sortKeysDesc() as $group) {
            $ranked = $ranked->concat(
                $this->resolveTiedGroup($category, $group->values(), $groupKey)
            );
        }

        return $ranked->values();
    }

    /**
     * @param  Collection<int, TournamentTeam>  $tied
     * @return Collection<int, TournamentTeam>
     */
    private function resolveTiedGroup(
        TournamentCategory $category,
        Collection $tied,
        ?string $groupKey,
    ): Collection {
        if ($tied->count() <= 1) {
            return $tied;
        }

        $pointDiffGroups = $tied->groupBy(fn (TournamentTeam $team) => $team->pointDifferential());
        $resolved = collect();

        foreach ($pointDiffGroups->sortKeysDesc() as $pointGroup) {
            if ($pointGroup->count() === 1) {
                $resolved->push($pointGroup->first());

                continue;
            }

            $resolved = $resolved->concat(
                $this->resolveByHeadToHead($category, $pointGroup->values(), $groupKey)
            );
        }

        return $resolved;
    }

    /**
     * @param  Collection<int, TournamentTeam>  $tied
     * @return Collection<int, TournamentTeam>
     */
    private function resolveByHeadToHead(
        TournamentCategory $category,
        Collection $tied,
        ?string $groupKey,
    ): Collection {
        if ($tied->count() === 2) {
            $winner = $this->headToHeadWinner($category, $tied[0], $tied[1], $groupKey);

            if ($winner !== null) {
                $loser = $winner->id === $tied[0]->id ? $tied[1] : $tied[0];

                return collect([$winner, $loser]);
            }
        }

        $records = $tied->mapWithKeys(function (TournamentTeam $team) use ($category, $tied, $groupKey) {
            $wins = 0;
            foreach ($tied as $opponent) {
                if ($opponent->id === $team->id) {
                    continue;
                }

                $winner = $this->headToHeadWinner($category, $team, $opponent, $groupKey);
                if ($winner?->id === $team->id) {
                    $wins++;
                }
            }

            return [$team->id => $wins];
        });

        return $tied->sortByDesc(fn (TournamentTeam $team) => $records[$team->id])->values();
    }

    private function headToHeadWinner(
        TournamentCategory $category,
        TournamentTeam $teamA,
        TournamentTeam $teamB,
        ?string $groupKey,
        array $phases = ['round_robin'],
    ): ?TournamentTeam {
        $query = TournamentMatch::query()
            ->where('tournament_category_id', $category->id)
            ->whereIn('phase', $phases)
            ->where('status', 'finished')
            ->where(function ($q) use ($teamA, $teamB) {
                $q->where(function ($inner) use ($teamA, $teamB) {
                    $inner->where('team_a_id', $teamA->id)->where('team_b_id', $teamB->id);
                })->orWhere(function ($inner) use ($teamA, $teamB) {
                    $inner->where('team_a_id', $teamB->id)->where('team_b_id', $teamA->id);
                });
            });

        if ($groupKey !== null) {
            $query->where('group_key', $groupKey);
        }

        $match = $query
            ->orderByDesc('id')
            ->first();

        if (! $match || ! $match->winner_team_id) {
            return null;
        }

        return $match->winner_team_id === $teamA->id ? $teamA : $teamB;
    }
}
