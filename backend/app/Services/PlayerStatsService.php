<?php

namespace App\Services;

use App\Models\PlaySession;
use App\Models\Player;

class PlayerStatsService
{
    public function __construct(private ClubPlayerService $clubPlayerService) {}

    /**
     * @param  array<int, int>  $winnerRosterIds
     * @param  array<int, int>  $loserRosterIds
     */
    public function recordMatchOutcome(
        PlaySession $session,
        array $winnerRosterIds,
        array $loserRosterIds,
        int $winnerScore,
        int $loserScore,
    ): void {
        $rosterIds = array_merge($winnerRosterIds, $loserRosterIds);
        $rosterPlayers = Player::query()
            ->with('clubPlayer')
            ->whereIn('id', $rosterIds)
            ->get()
            ->keyBy('id');

        foreach ($winnerRosterIds as $rosterId) {
            $this->recordForRosterPlayer(
                $session,
                $rosterPlayers->get($rosterId),
                true,
                $winnerScore,
                $loserScore,
            );
        }

        foreach ($loserRosterIds as $rosterId) {
            $this->recordForRosterPlayer(
                $session,
                $rosterPlayers->get($rosterId),
                false,
                $loserScore,
                $winnerScore,
            );
        }
    }

    private function recordForRosterPlayer(
        PlaySession $session,
        ?Player $rosterPlayer,
        bool $won,
        int $pointsScored,
        int $pointsAllowed,
    ): void {
        if (! $rosterPlayer) {
            return;
        }

        $clubPlayer = $rosterPlayer->clubPlayer;
        if ($clubPlayer?->is_guest) {
            return;
        }

        if (! $clubPlayer) {
            $clubPlayer = $this->clubPlayerService->findByName($rosterPlayer->name);
            if (! $clubPlayer) {
                $clubPlayer = $this->clubPlayerService->register(
                    $rosterPlayer->name,
                    $rosterPlayer->skill_level ?? 'beginner',
                    $rosterPlayer->gender ?? 'male',
                );
            }
            $rosterPlayer->update(['club_player_id' => $clubPlayer->id]);
        }

        $sessionPlayer = $this->clubPlayerService->ensureSessionPlayer($session, $clubPlayer);

        if ($won) {
            $this->clubPlayerService->recordWin($clubPlayer->fresh(), $sessionPlayer->fresh());
        } else {
            $this->clubPlayerService->recordLoss($clubPlayer->fresh(), $sessionPlayer->fresh());
        }

        $this->clubPlayerService->recordPoints(
            $clubPlayer->fresh(),
            $sessionPlayer->fresh(),
            $pointsScored,
            $pointsAllowed,
        );
    }
}
