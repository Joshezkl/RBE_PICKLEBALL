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

# Vercel build env can expose malformed HTTP_* vars that break artisan boot.
export APP_URL="${APP_URL:-https://vercel-placeholder.local}"
if [[ ! "$APP_URL" =~ ^https?:// ]]; then
  APP_URL="${APP_URL#https://}"
  APP_URL="${APP_URL#http://}"
  export APP_URL="https://${APP_URL}"
fi
export REQUEST_URI="/"
export SCRIPT_NAME="/index.php"
unset HTTP_HOST HTTPS SERVER_NAME QUERY_STRING 2>/dev/null || true

# shellcheck disable=SC1091
source "$ROOT/scripts/vercel-env.sh"

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
  composer install --no-dev --optimize-autoloader --no-interaction --no-scripts
else
  "$COMPOSER_BIN" install --no-dev --optimize-autoloader --no-interaction --no-scripts
fi

echo "==> Discovering Laravel packages"
php artisan package:discover --ansi
php artisan config:clear --ansi

if [ -n "${APP_KEY:-}" ] \
  && [ -n "${DB_HOST:-}" ] \
  && [ -n "${DB_DATABASE:-}" ] \
  && [ -n "${DB_USERNAME:-}" ] \
  && [ -n "${DB_PASSWORD:-}" ]; then
  echo "==> Running database migrations (host=${DB_HOST}, database=${DB_DATABASE})"
  if ! php artisan migrate --force --no-ansi; then
    echo "ERROR: migrations failed — tables may be out of date. Fix DB_* env vars, TiDB allowlist (0.0.0.0/0), then redeploy." >&2
    php artisan migrate --force --no-ansi 2>&1 | tail -10 >&2 || true
    exit 1
  fi
else
  echo "==> DB not fully configured — skipping migrations (need DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD)"
fi
