<?php

namespace App\Services;

use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;
use Illuminate\Support\Collection;

class QueueService
{
    public function __construct(private MatchModeService $matchModeService) {}

    public function addNewPlayer(PlaySession $session, Player $player): void
    {
        $queueType = $this->matchModeService->routeNewPlayer($session, $player);
        $this->enqueue($session, $player, $queueType);
    }

    public function enqueue(PlaySession $session, Player $player, string $queueType): void
    {
        $maxPosition = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->max('position') ?? 0;

        QueueEntry::query()->updateOrCreate(
            ['play_session_id' => $session->id, 'player_id' => $player->id],
            ['queue_type' => $queueType, 'position' => $maxPosition + 1]
        );
    }

    public function enqueueAtFront(PlaySession $session, Player $player, string $queueType): void
    {
        QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->get()
            ->each(function (QueueEntry $entry, int $index) {
                $entry->update(['position' => $index + 2]);
            });

        QueueEntry::query()->updateOrCreate(
            ['play_session_id' => $session->id, 'player_id' => $player->id],
            ['queue_type' => $queueType, 'position' => 1]
        );
    }

    public function enqueueAtEnd(PlaySession $session, Player $player, string $queueType): void
    {
        $this->enqueue($session, $player, $queueType);
    }

    public function enqueueAtPosition(
        PlaySession $session,
        Player $player,
        string $queueType,
        int $position,
    ): void {
        $position = max(1, $position);

        QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->where('position', '>=', $position)
            ->orderByDesc('position')
            ->get()
            ->each(function (QueueEntry $entry) {
                $entry->update(['position' => $entry->position + 1]);
            });

        QueueEntry::query()->updateOrCreate(
            ['play_session_id' => $session->id, 'player_id' => $player->id],
            ['queue_type' => $queueType, 'position' => $position],
        );
    }

    public function enqueueWinners(PlaySession $session, array $playerIds): void
    {
        foreach ($playerIds as $playerId) {
            $player = Player::query()->findOrFail($playerId);
            $this->enqueue($session, $player, 'winner');
        }
    }

    public function enqueueLosers(PlaySession $session, array $playerIds): void
    {
        foreach ($playerIds as $playerId) {
            $player = Player::query()->findOrFail($playerId);
            $this->enqueue($session, $player, 'loser');
        }
    }

    /**
     * @return Collection<int, Player>
     */
    public function peekFromQueue(PlaySession $session, string $queueType, int $count): Collection
    {
        $entries = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->with(['player.clubPlayer'])
            ->limit($count * 3)
            ->get()
            ->filter(fn (QueueEntry $entry) => $entry->player->availability === 'active')
            ->take($count);

        if ($entries->count() < $count) {
            return collect();
        }

        return $entries->map(fn (QueueEntry $entry) => $entry->player);
    }

    public function queueDepth(PlaySession $session, string $queueType): int
    {
        return QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->whereHas('player', fn ($q) => $q->where('availability', 'active'))
            ->count();
    }

    /**
     * @return Collection<int, Player>
     */
    public function takeFromQueue(PlaySession $session, string $queueType, int $count): Collection
    {
        $entries = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->with(['player.clubPlayer'])
            ->get()
            ->filter(fn (QueueEntry $entry) => $entry->player->availability === 'active')
            ->take($count);

        if ($entries->count() < $count) {
            return collect();
        }

        $playerIds = $entries->pluck('player_id');
        QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->whereIn('player_id', $playerIds)
            ->delete();

        $this->reindexQueue($session, $queueType);

        return $entries->map(fn (QueueEntry $entry) => $entry->player);
    }

    public function removePlayer(PlaySession $session, Player $player): void
    {
        $entry = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('player_id', $player->id)
            ->first();

        if ($entry) {
            $queueType = $entry->queue_type;
            $entry->delete();
            $this->reindexQueue($session, $queueType);
        }
    }

    public function getQueues(PlaySession $session): array
    {
        $types = $this->matchModeService->queueTypesFor($session);
        $result = array_fill_keys($types, []);

        $entries = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->orderBy('queue_type')
            ->orderBy('position')
            ->with(['player.clubPlayer'])
            ->get();

        foreach ($entries as $entry) {
            if (! array_key_exists($entry->queue_type, $result)) {
                $result[$entry->queue_type] = [];
            }

            $result[$entry->queue_type][] = [
                'id' => $entry->player->id,
                'name' => $entry->player->name,
                'wins' => $entry->player->wins,
                'losses' => $entry->player->losses,
                'position' => $entry->position,
                'skillLevel' => $entry->player->skill_level,
                'gender' => $entry->player->gender,
                'availability' => $entry->player->availability,
                'isGuest' => (bool) $entry->player->clubPlayer?->is_guest,
            ];
        }

        return $result;
    }

    private function reindexQueue(PlaySession $session, string $queueType): void
    {
        $entries = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->get();

        foreach ($entries as $index => $entry) {
            $entry->update(['position' => $index + 1]);
        }
    }
}
