<?php

namespace App\Support;

use App\Events\SessionStateUpdated;
use App\Models\PlaySession;
use App\Services\StateService;
use App\Support\SessionCacheInvalidator;

trait BroadcastsSessionState
{
    protected function broadcastState(PlaySession $session): array
    {
        $state = app(StateService::class)->build($session);

        // Cache invalidation is primarily driven by model events, but flag this
        // session explicitly too so any write performed purely via the query
        // builder (which fires no model events) is still covered.
        app(SessionCacheInvalidator::class)->markSession($session->id);
        app(SessionCacheInvalidator::class)->markLeaderboard($session->id);

        event(new SessionStateUpdated($session->id, $state));

        return $state;
    }
}
