<?php

namespace App\Services;

use App\Models\PlaySession;
use App\Models\Player;
use App\Models\QueueEntry;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

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
        // Shift the whole queue up by one in a single statement, then seat the
        // player at the front (positions need not be gap-free; they are only
        // used for ordering).
        QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->increment('position');

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
            ->increment('position');

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
            ->whereHas('player', fn ($q) => $q->where('availability', 'active'))
            ->orderBy('position')
            ->with(['player.clubPlayer'])
            ->limit($count)
            ->get();

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
            ->whereHas('player', fn ($q) => $q->where('availability', 'active'))
            ->orderBy('position')
            ->with(['player.clubPlayer'])
            ->limit($count)
            ->get();

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

    public function movePlayer(
        PlaySession $session,
        Player $player,
        string $targetQueueType,
        int $targetPosition,
    ): void {
        $entry = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('player_id', $player->id)
            ->first();

        if (! $entry) {
            throw new \InvalidArgumentException('Player is not in a queue');
        }

        $sourceQueueType = $entry->queue_type;
        $sourcePosition = $entry->position;
        $targetPosition = max(1, $targetPosition);

        if ($sourceQueueType === $targetQueueType) {
            $queueCount = QueueEntry::query()
                ->where('play_session_id', $session->id)
                ->where('queue_type', $targetQueueType)
                ->count();

            $targetPosition = min($targetPosition, $queueCount);

            if ($sourcePosition === $targetPosition) {
                return;
            }

            if ($sourcePosition < $targetPosition) {
                QueueEntry::query()
                    ->where('play_session_id', $session->id)
                    ->where('queue_type', $targetQueueType)
                    ->whereBetween('position', [$sourcePosition + 1, $targetPosition])
                    ->decrement('position');
            } else {
                QueueEntry::query()
                    ->where('play_session_id', $session->id)
                    ->where('queue_type', $targetQueueType)
                    ->whereBetween('position', [$targetPosition, $sourcePosition - 1])
                    ->increment('position');
            }

            $entry->update(['position' => $targetPosition]);

            return;
        }

        $entry->delete();
        $this->reindexQueue($session, $sourceQueueType);

        $targetCount = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $targetQueueType)
            ->count();

        $targetPosition = min($targetPosition, $targetCount + 1);

        QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $targetQueueType)
            ->where('position', '>=', $targetPosition)
            ->increment('position');

        QueueEntry::query()->create([
            'play_session_id' => $session->id,
            'player_id' => $player->id,
            'queue_type' => $targetQueueType,
            'position' => $targetPosition,
        ]);
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
                'joinedAt' => $entry->created_at?->toIso8601String(),
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
        $ids = QueueEntry::query()
            ->where('play_session_id', $session->id)
            ->where('queue_type', $queueType)
            ->orderBy('position')
            ->pluck('id');

        if ($ids->isEmpty()) {
            return;
        }

        // Collapse the per-row update loop into a single CASE statement so
        // re-indexing costs one round trip instead of one per queue entry.
        $cases = '';
        foreach ($ids as $index => $id) {
            $cases .= 'WHEN '.(int) $id.' THEN '.($index + 1).' ';
        }

        QueueEntry::query()
            ->whereIn('id', $ids->all())
            ->update(['position' => DB::raw("CASE id {$cases}END")]);
    }
}
