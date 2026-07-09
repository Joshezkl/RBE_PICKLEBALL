<?php

return [
    'admin_pin' => env('ADMIN_PIN', '1234'),

    /*
    |--------------------------------------------------------------------------
    | Live-state micro-cache
    |--------------------------------------------------------------------------
    |
    | The /live, /state and /sessions/active endpoints are polled by every
    | connected client (admin, public board, check-in kiosks). Without a cache,
    | each poll re-runs the full state build against a (often remote) database,
    | so N pollers cause N rebuilds. A short TTL collapses concurrent identical
    | builds into one, and the cache is invalidated immediately on every write
    | (see App\Support\BroadcastsSessionState), so reads stay fresh.
    |
    | Set the TTLs to 0 to disable caching entirely. For the biggest win on
    | serverless/remote-DB deployments, point CACHE_STORE at redis (e.g. Upstash)
    | so cached reads never touch the database connection at all.
    |
    */

    'cache' => [
        // Lightweight polling payload (/live). Kept well below the client poll
        // interval so each session rebuilds at most a few times per minute.
        'live_ttl' => (int) env('RPC_LIVE_CACHE_TTL', 5),

        // Heavy full state (/state, /sessions/active).
        'state_ttl' => (int) env('RPC_STATE_CACHE_TTL', 8),

        // Leaderboards only change when a match is scored; they are also
        // invalidated on write, so a longer TTL is safe.
        'leaderboard_ttl' => (int) env('RPC_LEADERBOARD_CACHE_TTL', 60),

        // Tournament display polling (/tournaments/active).
        'tournament_ttl' => (int) env('RPC_TOURNAMENT_CACHE_TTL', 5),
    ],
];
