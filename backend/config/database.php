<?php

use Illuminate\Support\Str;

/**
 * @return non-empty-string|null
 */
if (! function_exists('tidbBundledCaPath')) {
    function tidbBundledCaPath(): ?string
    {
        $candidates = [];

        if (function_exists('base_path')) {
            $candidates[] = base_path('storage/certs/isrgrootx1.pem');
        }

        $candidates[] = dirname(__DIR__).'/storage/certs/isrgrootx1.pem';

        foreach ($candidates as $path) {
            if (is_readable($path)) {
                return $path;
            }
        }

        return null;
    }
}

/**
 * @return array<int, mixed>
 */
if (! function_exists('mysqlSslOptions')) {
    function mysqlSslOptions(): array
    {
        if (! extension_loaded('pdo_mysql')) {
            return [];
        }

        $sslCaAttr = defined('Pdo\Mysql::ATTR_SSL_CA')
            ? \Pdo\Mysql::ATTR_SSL_CA
            : PDO::MYSQL_ATTR_SSL_CA;
        $sslVerifyAttr = defined('Pdo\Mysql::ATTR_SSL_VERIFY_SERVER_CERT')
            ? \Pdo\Mysql::ATTR_SSL_VERIFY_SERVER_CERT
            : PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT;

        $options = [];

        $host = (string) env('DB_HOST', '');
        $isTidb = str_contains($host, 'tidbcloud.com');

        if ($isTidb) {
            $options[$sslVerifyAttr] = false;

            $ca = (string) env('MYSQL_ATTR_SSL_CA', '');
            if ($ca === '' || ! is_readable($ca)) {
                $ca = (string) (tidbBundledCaPath() ?? '');
            }

            if ($ca !== '' && is_readable($ca)) {
                $options[$sslCaAttr] = $ca;
            }

            return $options;
        }

        if (env('MYSQL_ATTR_SSL_CA')) {
            $ca = (string) env('MYSQL_ATTR_SSL_CA');
            if (is_readable($ca)) {
                $options[$sslCaAttr] = $ca;
            }
        }
        if (filter_var(env('MYSQL_ATTR_SSL_VERIFY_SERVER_CERT', false), FILTER_VALIDATE_BOOLEAN)) {
            $options[$sslVerifyAttr] = true;
        }

        return $options;
    }
}

/**
 * Connection-level PDO options (SSL + optional persistent connections).
 *
 * Establishing a TLS connection to a remote MySQL/TiDB host costs ~300-500ms
 * per request. Enabling DB_PERSISTENT lets the driver reuse an existing
 * connection on warm serverless instances and always-on hosts, removing that
 * handshake from the critical path on the vast majority of requests.
 *
 * @return array<int, mixed>
 */
if (! function_exists('mysqlConnectionOptions')) {
    function mysqlConnectionOptions(): array
    {
        $options = mysqlSslOptions();

        if (filter_var(env('DB_PERSISTENT', false), FILTER_VALIDATE_BOOLEAN)) {
            $options[PDO::ATTR_PERSISTENT] = true;
        }

        return $options;
    }
}

return [

    /*
    |--------------------------------------------------------------------------
    | Default Database Connection Name
    |--------------------------------------------------------------------------
    |
    | Here you may specify which of the database connections below you wish
    | to use as your default connection for database operations. This is
    | the connection which will be utilized unless another connection
    | is explicitly specified when you execute a query / statement.
    |
    */

    'default' => strtolower((string) env('DB_CONNECTION', 'sqlite')),

    /*
    |--------------------------------------------------------------------------
    | Database Connections
    |--------------------------------------------------------------------------
    |
    | Below are all of the database connections defined for your application.
    | An example configuration is provided for each database system which
    | is supported by Laravel. You're free to add / remove connections.
    |
    */

    'connections' => [

        'sqlite' => [
            'driver' => 'sqlite',
            'url' => env('DB_URL'),
            'database' => env('DB_DATABASE', database_path('database.sqlite')),
            'prefix' => '',
            'foreign_key_constraints' => env('DB_FOREIGN_KEYS', true),
            'busy_timeout' => null,
            'journal_mode' => null,
            'synchronous' => null,
            'transaction_mode' => 'DEFERRED',
        ],

        'mysql' => [
            'driver' => 'mysql',
            'url' => env('DB_URL'),
            'host' => trim((string) env('DB_HOST', '127.0.0.1')),
            'port' => env('DB_PORT', '3306'),
            'database' => trim((string) env('DB_DATABASE', 'laravel')),
            'username' => trim((string) env('DB_USERNAME', 'root')),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => env('DB_CHARSET', 'utf8mb4'),
            'collation' => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => mysqlConnectionOptions(),
        ],

        'mariadb' => [
            'driver' => 'mariadb',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => env('DB_CHARSET', 'utf8mb4'),
            'collation' => env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => mysqlConnectionOptions(),
        ],

        'pgsql' => [
            'driver' => 'pgsql',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => env('DB_CHARSET', 'utf8'),
            'prefix' => '',
            'prefix_indexes' => true,
            'search_path' => 'public',
            'sslmode' => env('DB_SSLMODE', 'prefer'),
        ],

        'sqlsrv' => [
            'driver' => 'sqlsrv',
            'url' => env('DB_URL'),
            'host' => env('DB_HOST', 'localhost'),
            'port' => env('DB_PORT', '1433'),
            'database' => env('DB_DATABASE', 'laravel'),
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => env('DB_CHARSET', 'utf8'),
            'prefix' => '',
            'prefix_indexes' => true,
            // 'encrypt' => env('DB_ENCRYPT', 'yes'),
            // 'trust_server_certificate' => env('DB_TRUST_SERVER_CERTIFICATE', 'false'),
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Migration Repository Table
    |--------------------------------------------------------------------------
    |
    | This table keeps track of all the migrations that have already run for
    | your application. Using this information, we can determine which of
    | the migrations on disk haven't actually been run on the database.
    |
    */

    'migrations' => [
        'table' => 'migrations',
        'update_date_on_publish' => true,
    ],

    /*
    |--------------------------------------------------------------------------
    | Redis Databases
    |--------------------------------------------------------------------------
    |
    | Redis is an open source, fast, and advanced key-value store that also
    | provides a richer body of commands than a typical key-value system
    | such as Memcached. You may define your connection settings here.
    |
    */

    'redis' => [

        'client' => env('REDIS_CLIENT', 'phpredis'),

        'options' => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix' => env('REDIS_PREFIX', Str::slug((string) env('APP_NAME', 'laravel')).'-database-'),
            'persistent' => env('REDIS_PERSISTENT', false),
        ],

        'default' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_DB', '0'),
            'max_retries' => env('REDIS_MAX_RETRIES', 3),
            'backoff_algorithm' => env('REDIS_BACKOFF_ALGORITHM', 'decorrelated_jitter'),
            'backoff_base' => env('REDIS_BACKOFF_BASE', 100),
            'backoff_cap' => env('REDIS_BACKOFF_CAP', 1000),
        ],

        'cache' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'username' => env('REDIS_USERNAME'),
            'password' => env('REDIS_PASSWORD'),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_CACHE_DB', '1'),
            'max_retries' => env('REDIS_MAX_RETRIES', 3),
            'backoff_algorithm' => env('REDIS_BACKOFF_ALGORITHM', 'decorrelated_jitter'),
            'backoff_base' => env('REDIS_BACKOFF_BASE', 100),
            'backoff_cap' => env('REDIS_BACKOFF_CAP', 1000),
        ],

    ],

];
