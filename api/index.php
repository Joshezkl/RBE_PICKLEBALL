<?php

declare(strict_types=1);

/**
 * Vercel serverless entry for the Laravel API (same project as Flutter web).
 */
$backendRoot = dirname(__DIR__).'/backend';
$publicRoot = $backendRoot.'/public';

if (getenv('VERCEL') || getenv('VERCEL_ENV') || getenv('VERCEL_URL')) {
    $tmp = sys_get_temp_dir().'/rbe';
    foreach (["{$tmp}/views", "{$tmp}/cache", "{$tmp}/sessions"] as $dir) {
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
    }
    $_ENV['VIEW_COMPILED_PATH'] = "{$tmp}/views";
    $_SERVER['VIEW_COMPILED_PATH'] = "{$tmp}/views";

    foreach (['config.php', 'routes-v7.php', 'events.php', 'services.php'] as $cacheFile) {
        $path = $backendRoot.'/bootstrap/cache/'.$cacheFile;
        if (is_file($path)) {
            @unlink($path);
        }
    }

    // Inject Vercel env vars into Laravel without putenv (passwords may contain = or ;).
    foreach ([
        'APP_KEY', 'APP_ENV', 'APP_DEBUG', 'APP_URL',
        'DB_CONNECTION', 'DB_URL', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD',
        'MYSQL_ATTR_SSL_CA', 'MYSQL_ATTR_SSL_VERIFY_SERVER_CERT',
        'ADMIN_PIN', 'LOG_CHANNEL',
    ] as $envKey) {
        $value = getenv($envKey);
        if ($value !== false) {
            if ($envKey === 'DB_CONNECTION') {
                $value = strtolower(trim($value));
            }
            $_ENV[$envKey] = $value;
            $_SERVER[$envKey] = $value;
        }
    }
}

$onVercel = (bool) (getenv('VERCEL') ?: getenv('VERCEL_ENV') ?: getenv('VERCEL_URL'));
$dbConnection = strtolower(trim((string) (getenv('DB_CONNECTION') ?: ($_ENV['DB_CONNECTION'] ?? 'sqlite'))));
if ($onVercel && $dbConnection === 'mysql') {
    $missingDb = [];
    foreach (['DB_HOST', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD'] as $envKey) {
        $value = getenv($envKey);
        if ($value === false || trim((string) $value) === '') {
            $missingDb[] = $envKey;
        }
    }
    if ($missingDb !== []) {
        http_response_code(503);
        header('Content-Type: application/json');
        echo json_encode([
            'message' => 'Database not configured for Vercel',
            'error' => 'Missing: '.implode(', ', $missingDb).'. Add MySQL env vars in Vercel → Settings → Environment Variables (enable for Preview and Production), then redeploy.',
        ], JSON_UNESCAPED_SLASHES);
        exit;
    }
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
