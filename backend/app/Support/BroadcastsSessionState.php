<?php

namespace App\Support;

use App\Events\SessionStateUpdated;
use App\Models\PlaySession;
use App\Services\StateService;

trait BroadcastsSessionState
{
    protected function broadcastState(PlaySession $session): array
    {
        $state = app(StateService::class)->build($session);
        event(new SessionStateUpdated($session->id, $state));

        return $state;
    }
}
