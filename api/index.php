<?php

declare(strict_types=1);

/**
 * Vercel serverless entry for the Laravel API (same project as Flutter web).
 */
$backendRoot = dirname(__DIR__).'/backend';

if (getenv('VERCEL')) {
    $tmp = sys_get_temp_dir().'/rbe';
    foreach (["{$tmp}/views", "{$tmp}/cache", "{$tmp}/sessions"] as $dir) {
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
    }
    putenv("VIEW_COMPILED_PATH={$tmp}/views");
    $_ENV['VIEW_COMPILED_PATH'] = "{$tmp}/views";
}

/**
 * Vercel rewrites /api/* to this file but often forwards a path without the /api
 * prefix. Laravel registers API routes under the /api prefix, so restore it here.
 */
(function (): void {
    $uri = $_SERVER['REQUEST_URI'] ?? '/';
    $path = parse_url($uri, PHP_URL_PATH) ?: '/';
    $query = parse_url($uri, PHP_URL_QUERY);

    if (str_starts_with($path, '/api/index.php')) {
        $suffix = substr($path, strlen('/api/index.php'));
        $path = '/api'.($suffix === '' ? '' : $suffix);
    } elseif (! str_starts_with($path, '/api')) {
        $path = '/api'.(str_starts_with($path, '/') ? $path : '/'.$path);
    }

    $_SERVER['REQUEST_URI'] = $path.($query ? '?'.$query : '');
})();

require $backendRoot.'/vendor/autoload.php';

$app = require_once $backendRoot.'/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);

$request = Illuminate\Http\Request::capture();
$response = $kernel->handle($request);
$response->send();

$kernel->terminate($request, $response);
