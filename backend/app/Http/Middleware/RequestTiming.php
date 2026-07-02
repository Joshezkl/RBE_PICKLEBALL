<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class RequestTiming
{
    public function handle(Request $request, Closure $next): Response
    {
        $started = microtime(true);

        /** @var Response $response */
        $response = $next($request);

        $durationMs = round((microtime(true) - $started) * 1000, 1);

        $response->headers->set('X-Response-Time-Ms', (string) $durationMs);
        $response->headers->set('Server-Timing', "app;dur={$durationMs}");

        if ($durationMs >= 2000) {
            Log::warning('Slow API request', [
                'method' => $request->method(),
                'path' => $request->path(),
                'duration_ms' => $durationMs,
                'status' => $response->getStatusCode(),
            ]);
        }

        return $response;
    }
}
