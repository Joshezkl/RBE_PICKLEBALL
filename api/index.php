<?php

declare(strict_types=1);

/**
 * Vercel serverless entry for the Laravel API (same project as Flutter web).
 */
$backendRoot = dirname(__DIR__).'/backend';
$publicRoot = $backendRoot.'/public';

require __DIR__.'/vercel-env.php';

if (getenv('VERCEL') || getenv('VERCEL_ENV') || getenv('VERCEL_URL')) {
    $tmp = sys_get_temp_dir().'/rbe';
    foreach (["{$tmp}/views", "{$tmp}/cache", "{$tmp}/sessions"] as $dir) {
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
    }
    $_ENV['VIEW_COMPILED_PATH'] = "{$tmp}/views";
    $_SERVER['VIEW_COMPILED_PATH'] = "{$tmp}/views";

    // Stale config cache breaks runtime DB/SSL env on serverless; route cache is safe to keep.
    $configCache = $backendRoot.'/bootstrap/cache/config.php';
    if (is_file($configCache)) {
        @unlink($configCache);
    }
}

$onVercel = (bool) (getenv('VERCEL') ?: getenv('VERCEL_ENV') ?: getenv('VERCEL_URL'));
$envValues = rbe_vercel_env_map();
if ($onVercel) {
    rbe_inject_env($envValues);
    rbe_sanitize_runtime_ssl_env($envValues);
}

$envError = rbe_validate_mysql_env($onVercel, $envValues);
if ($envError !== null) {
    http_response_code(503);
    header('Content-Type: application/json');
    echo json_encode($envError, JSON_UNESCAPED_SLASHES);
    exit;
}

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

$autoload = $backendRoot.'/vendor/autoload.php';
if (! is_file($autoload)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'message' => 'API bootstrap failed',
        'error' => 'Missing backend/vendor. Redeploy so the Vercel PHP build runs composer install (root composer.json "vercel" script).',
    ], JSON_UNESCAPED_SLASHES);
    exit;
}

chdir($publicRoot);

try {
    require $publicRoot.'/index.php';
} catch (Throwable $exception) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'message' => 'API bootstrap failed',
        'error' => $exception->getMessage(),
    ], JSON_UNESCAPED_SLASHES);
}
