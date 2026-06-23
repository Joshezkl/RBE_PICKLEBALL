<?php

namespace App\Services;

use App\Models\Tournament;
use App\Models\TournamentMatch;
use App\Models\TournamentTeam;
use Illuminate\Support\Facades\DB;

class TournamentMatchService
{
    public function __construct(
        private TournamentScheduleService $scheduleService,
    ) {}

    public function score(Tournament $tournament, TournamentMatch $match, int $scoreA, int $scoreB): void
    {
        if ($match->tournament_id !== $tournament->id) {
            throw new \InvalidArgumentException('Match does not belong to this tournament');
        }

        if ($match->status === 'finished') {
            throw new \RuntimeException('Match is already finished');
        }

        if ($match->status !== 'on_court') {
            throw new \RuntimeException('Assign the match to the court before entering a score');
        }

        if ($scoreA === $scoreB) {
            throw new \InvalidArgumentException('Ties are not allowed — enter a winning score');
        }

        if ($scoreA < 0 || $scoreB < 0) {
            throw new \InvalidArgumentException('Scores must be zero or greater');
        }

        $winnerTeamId = $scoreA > $scoreB ? $match->team_a_id : $match->team_b_id;
        $loserTeamId = $scoreA > $scoreB ? $match->team_b_id : $match->team_a_id;
        DB::transaction(function () use ($match, $scoreA, $scoreB, $winnerTeamId, $loserTeamId) {
            $match->update([
                'score_a' => $scoreA,
                'score_b' => $scoreB,
                'winner_team_id' => $winnerTeamId,
                'status' => 'finished',
                'court_number' => null,
            ]);

            if (in_array($match->phase, ['round_robin', 'final_round_robin'], true)) {
                $this->updateRoundRobinStats($match, $winnerTeamId, $loserTeamId, $scoreA, $scoreB);
            }

            if (in_array($match->phase, ['single_elimination', 'third_place'], true) && $loserTeamId) {
                TournamentTeam::query()->where('id', $loserTeamId)->update(['status' => 'eliminated']);
            }

            if ($match->phase === 'single_elimination' && $winnerTeamId && $match->feeds_into_match_id) {
                $this->advanceWinnerToNextMatch($match, $winnerTeamId);
            }
        });

        $category = $match->category()->firstOrFail();

        if ($match->phase === 'round_robin' && $this->scheduleService->roundRobinComplete($category)) {
            $this->scheduleService->advanceToSingleElimination(
                $category->fresh(),
                $tournament->fresh(),
            );
        }

        if ($match->phase === 'final_round_robin'
            && $this->scheduleService->finalRoundRobinComplete($category->fresh())) {
            $this->scheduleService->finalizeFinalRoundRobin($category->fresh());
        }

        if ($match->phase === 'tiebreaker') {
            $this->scheduleService->finalizeFinalRoundRobin($category->fresh());
        }

        if (in_array($match->phase, ['single_elimination', 'third_place'], true)) {
            $freshCategory = $category->fresh();

            if ($match->phase === 'single_elimination') {
                $this->scheduleService->maybeCreateThirdPlaceMatch($freshCategory);
            }

            if ($this->scheduleService->playoffsComplete($freshCategory->fresh())) {
                $this->scheduleService->finalizeCategory($freshCategory->fresh());
            }
        }

        $this->syncTournamentStatus($tournament->fresh());
    }

    private function advanceWinnerToNextMatch(TournamentMatch $match, int $winnerTeamId): void
    {
        $next = TournamentMatch::query()->find($match->feeds_into_match_id);

        if (! $next) {
            return;
        }

        $field = $match->feed_slot === 'team_b' ? 'team_b_id' : 'team_a_id';
        $next->update([$field => $winnerTeamId]);
    }

    private function updateRoundRobinStats(
        TournamentMatch $match,
        ?int $winnerTeamId,
        ?int $loserTeamId,
        int $scoreA,
        int $scoreB,
    ): void {
        if ($winnerTeamId) {
            $winner = TournamentTeam::query()->find($winnerTeamId);
            if ($winner) {
                $winner->increment('wins');
                $winner->increment('points_scored', $winnerTeamId === $match->team_a_id ? $scoreA : $scoreB);
                $winner->increment('points_allowed', $winnerTeamId === $match->team_a_id ? $scoreB : $scoreA);
            }
        }

        if ($loserTeamId) {
            $loser = TournamentTeam::query()->find($loserTeamId);
            if ($loser) {
                $loser->increment('losses');
                $loser->increment('points_scored', $loserTeamId === $match->team_a_id ? $scoreA : $scoreB);
                $loser->increment('points_allowed', $loserTeamId === $match->team_a_id ? $scoreB : $scoreA);
            }
        }
    }

    private function syncTournamentStatus(Tournament $tournament): void
    {
        $enabledCategories = $tournament->categories()->where('is_enabled', true)->get();

        if ($enabledCategories->isEmpty()) {
            return;
        }

        $allCompleted = $enabledCategories->every(fn ($category) => $category->phase === 'completed');

        if ($allCompleted) {
            $tournament->update([
                'status' => 'completed',
                'ended_at' => now(),
            ]);

            return;
        }

        $anyFinalRoundRobin = $enabledCategories->contains(
            fn ($category) => $category->phase === 'final_round_robin'
        );
        $anyElim = $enabledCategories->contains(fn ($category) => $category->phase === 'single_elimination');
        $anyRoundRobin = $enabledCategories->contains(fn ($category) => $category->phase === 'round_robin');

        if ($anyFinalRoundRobin) {
            $tournament->update(['status' => 'final_round_robin']);

            return;
        }

        if ($anyElim) {
            $tournament->update(['status' => 'single_elimination']);

            return;
        }

        if ($anyRoundRobin) {
            $tournament->update(['status' => 'round_robin']);
        }
    }
}
