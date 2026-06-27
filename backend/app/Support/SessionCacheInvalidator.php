<?php

namespace App\Support;

use App\Services\LeaderboardService;
use App\Services\StateService;

/**
 * Collects which sessions were mutated during a request and flushes their
 * cached payloads once, after the response is sent (see AppServiceProvider).
 *
 * Driven by model events rather than controllers, so cache correctness does
 * not depend on every write path remembering to invalidate. Deferring the
 * flush to the terminating phase means it adds no latency to the response and
 * collapses the many model writes of a single request into one forget per key.
 */
class SessionCacheInvalidator
{
    /** @var array<int, true> */
    private array $dirtySessions = [];

    /** @var array<int, true> */
    private array $leaderboardSessions = [];

    private bool $leaderboardDirty = false;

    public function markSession(?int $sessionId): void
    {
        if ($sessionId !== null) {
            $this->dirtySessions[$sessionId] = true;
        }
    }

    public function markLeaderboard(?int $sessionId = null): void
    {
        $this->leaderboardDirty = true;

        if ($sessionId !== null) {
            $this->leaderboardSessions[$sessionId] = true;
        }
    }

    public function flush(): void
    {
        foreach (array_keys($this->dirtySessions) as $sessionId) {
            StateService::invalidate($sessionId);
        }

        if ($this->leaderboardDirty) {
            LeaderboardService::invalidate();

            foreach (array_keys($this->leaderboardSessions) as $sessionId) {
                LeaderboardService::invalidate($sessionId);
            }
        }

        $this->dirtySessions = [];
        $this->leaderboardSessions = [];
        $this->leaderboardDirty = false;
    }
}
