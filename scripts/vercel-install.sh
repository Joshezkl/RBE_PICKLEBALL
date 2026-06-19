#!/usr/bin/env bash
# Install Composer and Laravel vendor/ on Vercel build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash "$ROOT/scripts/vercel-install-php.sh"

if [ -f "$ROOT/.vercel-php-path.sh" ]; then
  # shellcheck disable=SC1090
  source "$ROOT/.vercel-php-path.sh"
fi

COMPOSER_BIN="${COMPOSER_BIN:-/tmp/composer}"
if ! command -v composer >/dev/null 2>&1; then
  echo "==> Downloading Composer"
  curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
  php /tmp/composer-setup.php --install-dir=/tmp --filename=composer
  rm -f /tmp/composer-setup.php
  COMPOSER_BIN="/tmp/composer"
fi

echo "==> Installing Laravel dependencies"
cd "$ROOT/backend"
if command -v composer >/dev/null 2>&1; then
  composer install --no-dev --optimize-autoloader --no-interaction
else
  "$COMPOSER_BIN" install --no-dev --optimize-autoloader --no-interaction
fi

if [ -n "${APP_KEY:-}" ]; then
  if [ -n "${DB_HOST:-}" ] || [ "${DB_CONNECTION:-}" = "sqlite" ]; then
    echo "==> Running database migrations"
    php artisan migrate --force --no-ansi
  fi
else
  echo "==> APP_KEY not set — skipping Laravel migrations"
fi
