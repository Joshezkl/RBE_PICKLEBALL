<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
        apiPrefix: 'api',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->trustProxies(at: '*');

        $middleware->api(prepend: [
            \Illuminate\Http\Middleware\HandleCors::class,
            \App\Http\Middleware\RequestTiming::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (QueryException $exception, Request $request) {
            if (! $request->is('api/*') || ! $request->expectsJson()) {
                return null;
            }

            $detail = $exception->getMessage();
            $hint = 'Add MySQL variables (DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD) in Vercel project settings, enable them for Preview and Production, then redeploy.';

            if (str_contains($detail, 'Access denied')) {
                $hint = 'Database credentials were rejected. Check DB_USERNAME and DB_PASSWORD in Vercel env vars.';
            } elseif (str_contains($detail, 'Unknown database')) {
                $hint = 'Database does not exist yet. Create it in your MySQL provider (e.g. rpc_queue), then redeploy so migrations can run.';
            } elseif (str_contains($detail, "doesn't exist") || str_contains($detail, 'no such table')) {
                $hint = 'Database is reachable but tables are missing. Redeploy with DB_* vars set so migrations run during the Vercel build.';
            } elseif (str_contains($detail, 'getaddrinfo') || str_contains($detail, 'php_network_getaddresses')) {
                $hint = 'Vercel cannot resolve or reach the database host. Re-enter DB_HOST without spaces or https://, set DB_PORT=4000 for TiDB, and in TiDB Cloud enable a public endpoint with IP allowlist 0.0.0.0/0.';
            } elseif (str_contains($detail, 'Connection refused') || str_contains($detail, 'timed out')) {
                $hint = 'Cannot reach the database host. Check DB_HOST, DB_PORT, and allow external connections from your MySQL provider.';
            } elseif (str_contains($detail, 'Cannot connect to MySQL using SSL') || str_contains($detail, 'SSL connection')) {
                $hint = 'TiDB SSL failed on Vercel. Redeploy with the bundled CA at backend/storage/certs/isrgrootx1.pem and MYSQL_ATTR_SSL_VERIFY_SERVER_CERT=false.';
            } elseif (str_contains($detail, 'insecure transport are prohibited')) {
                $hint = 'TiDB requires TLS. Redeploy so the app can use the bundled ISRG Root X1 CA (backend/storage/certs/isrgrootx1.pem).';
            } elseif (str_contains($detail, 'Data too long for column')) {
                return response()->json([
                    'message' => 'Database schema is out of date. Redeploy so the latest migrations can widen tournament category keys.',
                    'error' => $detail,
                ], 500);
            }

            return response()->json([
                'message' => 'Database not connected. '.$hint,
                'error' => $detail,
            ], 503);
        });
    })->create();
