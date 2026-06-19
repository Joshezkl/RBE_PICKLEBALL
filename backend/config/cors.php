<?php

$frontendOrigins = env('FRONTEND_URL');

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => filled($frontendOrigins)
        ? array_values(array_filter(array_map('trim', explode(',', (string) $frontendOrigins))))
        : ['*'],
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
