<?php

declare(strict_types=1);

/**
 * Vercel serverless entry for the Laravel API (same project as Flutter web).
 */
$backendRoot = dirname(__DIR__).'/backend';
$publicRoot = $backendRoot.'/public';

if (getenv('VERCEL')) {
    $tmp = sys_get_temp_dir().'/rbe';
    foreach (["{$tmp}/views", "{$tmp}/cache", "{$tmp}/sessions"] as $dir) {
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
    }
    putenv("VIEW_COMPILED_PATH={$tmp}/views");
    $_ENV['VIEW_COMPILED_PATH'] = "{$tmp}/views";

    // Ensure Vercel project env vars are visible to Laravel (no .env on serverless).
    $configCache = $backendRoot.'/bootstrap/cache/config.php';
    if (is_file($configCache)) {
        unlink($configCache);
    }

    foreach ([
        'APP_KEY', 'APP_ENV', 'APP_DEBUG', 'APP_URL',
        'DB_CONNECTION', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD',
        'ADMIN_PIN', 'LOG_CHANNEL',
    ] as $envKey) {
        $value = getenv($envKey);
        if ($value !== false && $value !== '') {
            putenv("{$envKey}={$value}");
            $_ENV[$envKey] = $value;
            $_SERVER[$envKey] = $value;
        }
    }
}

/**
 * Vercel rewrites /api/* to this file. Normalize the URI so Laravel sees
 * /api/health, /api/sessions/active, etc. (not health or sessions alone).
 */
$rawUri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($rawUri, PHP_URL_PATH) ?: '/';
$query = parse_url($rawUri, PHP_URL_QUERY);

if (str_starts_with($path, '/api/index.php')) {
    $path = '/api'.substr($path, strlen('/api/index.php'));
}
if (! str_starts_with($path, '/api')) {
    $path = '/api'.(str_starts_with($path, '/') ? $path : '/'.$path);
}

$_SERVER['REQUEST_URI'] = $path.($query ? '?'.$query : '');
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['SCRIPT_FILENAME'] = $publicRoot.'/index.php';
unset($_SERVER['PATH_INFO']);

chdir($publicRoot);

require $publicRoot.'/index.php';
