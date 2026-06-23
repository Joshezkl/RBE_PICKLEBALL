<?php

declare(strict_types=1);

/**
 * Normalize Vercel / TiDB integration env vars for Laravel.
 */
function rbe_sanitize_env_value(string $value): string
{
    $value = trim($value);
    $value = trim($value, "\"'");

    return str_replace(["\r", "\n"], '', $value);
}

/**
 * @return array<string, string>
 */
function rbe_vercel_env_map(): array
{
    $keys = [
        'APP_KEY', 'APP_ENV', 'APP_DEBUG', 'APP_URL',
        'DB_CONNECTION', 'DB_URL', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD',
        'MYSQL_ATTR_SSL_CA', 'MYSQL_ATTR_SSL_VERIFY_SERVER_CERT',
        'ADMIN_PIN', 'LOG_CHANNEL',
    ];

    $values = [];

    foreach ($keys as $key) {
        $raw = getenv($key);
        if ($raw === false) {
            continue;
        }

        $value = rbe_sanitize_env_value((string) $raw);
        if ($key === 'DB_CONNECTION') {
            $value = strtolower($value);
        }

        $values[$key] = $value;
    }

    // TiDB Cloud Vercel integration uses TIDB_* instead of DB_*.
    $tidbMap = [
        'TIDB_HOST' => 'DB_HOST',
        'TIDB_PORT' => 'DB_PORT',
        'TIDB_USER' => 'DB_USERNAME',
        'TIDB_PASSWORD' => 'DB_PASSWORD',
        'TIDB_DATABASE' => 'DB_DATABASE',
    ];

    foreach ($tidbMap as $from => $to) {
        $raw = getenv($from);
        if ($raw === false || ($values[$to] ?? '') !== '') {
            continue;
        }

        $values[$to] = rbe_sanitize_env_value((string) $raw);
    }

    if (($values['DB_HOST'] ?? '') === '' && ($values['DB_URL'] ?? '') !== '') {
        $parsed = parse_url($values['DB_URL']);
        if (is_array($parsed)) {
            if (! empty($parsed['host'])) {
                $values['DB_HOST'] = $parsed['host'];
            }
            if (! empty($parsed['port'])) {
                $values['DB_PORT'] = (string) $parsed['port'];
            }
            if (! empty($parsed['user'])) {
                $values['DB_USERNAME'] = rawurldecode($parsed['user']);
            }
            if (array_key_exists('pass', $parsed) && $parsed['pass'] !== null) {
                $values['DB_PASSWORD'] = rawurldecode((string) $parsed['pass']);
            }
            if (! empty($parsed['path'])) {
                $values['DB_DATABASE'] = ltrim($parsed['path'], '/');
            }
            if (($values['DB_CONNECTION'] ?? '') === '') {
                $values['DB_CONNECTION'] = 'mysql';
            }
        }
    }

    if (($values['DB_HOST'] ?? '') !== '' && str_contains($values['DB_HOST'], ':')) {
        [$host, $port] = array_pad(explode(':', $values['DB_HOST'], 2), 2, null);
        if ($host !== '') {
            $values['DB_HOST'] = $host;
        }
        if ($port !== null && $port !== '' && ($values['DB_PORT'] ?? '') === '') {
            $values['DB_PORT'] = $port;
        }
    }

    if (($values['DB_CONNECTION'] ?? '') === '') {
        $values['DB_CONNECTION'] = 'mysql';
    }

    if (($values['DB_PORT'] ?? '') === '') {
        $values['DB_PORT'] = str_contains((string) ($values['DB_HOST'] ?? ''), 'tidbcloud.com')
            ? '4000'
            : '3306';
    }

    if (
        str_contains((string) ($values['DB_HOST'] ?? ''), 'tidbcloud.com')
        && ($values['MYSQL_ATTR_SSL_VERIFY_SERVER_CERT'] ?? '') === ''
    ) {
        $values['MYSQL_ATTR_SSL_VERIFY_SERVER_CERT'] = 'false';
    }

    if (
        str_contains((string) ($values['DB_HOST'] ?? ''), 'tidbcloud.com')
        && ($values['MYSQL_ATTR_SSL_CA'] ?? '') === ''
    ) {
        foreach ([
            '/etc/pki/tls/certs/ca-bundle.crt',
            '/etc/ssl/certs/ca-certificates.crt',
        ] as $caBundle) {
            if (is_file($caBundle)) {
                $values['MYSQL_ATTR_SSL_CA'] = $caBundle;
                break;
            }
        }
    }

    return $values;
}

/**
 * @param array<string, string> $values
 */
function rbe_inject_env(array $values): void
{
    foreach ($values as $key => $value) {
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;
    }
}

/**
 * @param array<string, string> $values
 */
function rbe_validate_mysql_env(bool $onVercel, array $values): ?array
{
    if (! $onVercel || ($values['DB_CONNECTION'] ?? 'sqlite') !== 'mysql') {
        return null;
    }

    $missing = [];
    foreach (['DB_HOST', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD'] as $key) {
        if (($values[$key] ?? '') === '') {
            $missing[] = $key;
        }
    }

    if ($missing !== []) {
        return [
            'message' => 'Database not configured for Vercel',
            'error' => 'Missing: '.implode(', ', $missing).'. Use DB_* vars or install the TiDB Cloud Vercel integration (TIDB_* vars). Enable for Preview and Production, then redeploy.',
        ];
    }

    $host = $values['DB_HOST'];
    if (! preg_match('/^[a-zA-Z0-9.-]+$/', $host)) {
        return [
            'message' => 'Invalid DB_HOST value',
            'error' => 'DB_HOST contains unexpected characters. Paste only the hostname (no https://, spaces, or port). Example: gateway01.ap-southeast-1.prod.aws.tidbcloud.com with DB_PORT=4000.',
        ];
    }

    return null;
}
