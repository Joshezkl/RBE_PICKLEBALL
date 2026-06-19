<?php

namespace App\Services;

use App\Models\MatchGame;
use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;

class PlayerAvailabilityService
{
    public function __construct(private QueueService $queueService) {}

    public function stepOut(PlaySession $session, Player $player): Player
    {
        if (! $player->is_active) {
            throw new \RuntimeException('Player is not active in this session');
        }

        if ($player->availability === 'away') {
            return $player;
        }

        $this->assertNotOnCourt($session, $player);

        $entry = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('player_id', $player->id)
            ->first();

        $player->update([
            'availability' => 'away',
            'away_queue_type' => $entry?->queue_type,
            'away_queue_position' => $entry?->position,
        ]);

        if ($entry) {
            $this->queueService->removePlayer($session, $player);
        }

        return $player->fresh();
    }

    public function stepBack(PlaySession $session, Player $player): Player
    {
        if (! $player->is_active) {
            throw new \RuntimeException('Player is not active in this session');
        }

        if ($player->availability !== 'away') {
            return $player;
        }

        $queueType = $player->away_queue_type;
        $queuePosition = $player->away_queue_position;

        $player->update([
            'availability' => 'active',
            'away_queue_type' => null,
            'away_queue_position' => null,
        ]);

        if ($queueType !== null && $queuePosition !== null) {
            $this->queueService->enqueueAtPosition($session, $player->fresh(), $queueType, $queuePosition);
        } else {
            $this->queueService->addNewPlayer($session->fresh(), $player->fresh());
        }

        return $player->fresh();
    }

    private function assertNotOnCourt(PlaySession $session, Player $player): void
    {
        $onCourt = MatchGame::query()
            ->where('play_session_id', $session->id)
            ->where('status', 'in_match')
            ->where(function ($q) use ($player) {
                $q->where('team_a_player1', $player->id)
                    ->orWhere('team_a_player2', $player->id)
                    ->orWhere('team_b_player1', $player->id)
                    ->orWhere('team_b_player2', $player->id);
            })
            ->exists();

        if ($onCourt) {
            throw new \RuntimeException('Cannot step out while on court');
        }
    }
}
