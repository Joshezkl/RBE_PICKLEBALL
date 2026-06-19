<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class VerifyAdminPin
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = config('rpc.admin_pin');
        $provided = $request->header('X-Admin-Pin');

        if (! $expected || ! $provided || ! hash_equals((string) $expected, (string) $provided)) {
            return response()->json(['message' => 'Invalid or missing admin PIN'], 401);
        }

        return $next($request);
    }
}
