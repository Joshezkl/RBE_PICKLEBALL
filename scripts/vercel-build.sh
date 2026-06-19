#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Generating runtime env-config.js"
node scripts/generate-env-config.mjs frontend/web/env-config.js

echo "==> Installing Laravel dependencies"
cd "$ROOT/backend"
if ! command -v composer >/dev/null 2>&1; then
  echo "==> Composer not found — downloading"
  curl -sS https://getcomposer.org/installer | php -- --install-dir="$ROOT" --filename=composer
  export PATH="$ROOT:$PATH"
fi
composer install --no-dev --optimize-autoloader --no-interaction

if [ -n "${APP_KEY:-}" ]; then
  if [ -n "${DB_HOST:-}" ] || [ "${DB_CONNECTION:-}" = "sqlite" ]; then
    php artisan migrate --force --no-ansi || true
  fi
else
  echo "==> APP_KEY not set — skipping Laravel migrations"
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Flutter not found — installing stable SDK"
  export FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
  if [ ! -d "$FLUTTER_HOME/bin" ]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME"
  fi
  export PATH="$FLUTTER_HOME/bin:$PATH"
  flutter config --enable-web
  flutter precache --web
fi

echo "==> Building Flutter web release"
cd "$ROOT/frontend"
flutter pub get

BUILD_ARGS=(build web --release)

if [ -n "${API_BASE_URL:-}" ]; then
  BUILD_ARGS+=(--dart-define="API_BASE_URL=${API_BASE_URL}")
fi
if [ -n "${WS_HOST:-}" ]; then
  BUILD_ARGS+=(--dart-define="WS_HOST=${WS_HOST}")
fi
if [ -n "${WS_SCHEME:-}" ]; then
  BUILD_ARGS+=(--dart-define="WS_SCHEME=${WS_SCHEME}")
fi
if [ -n "${WS_KEY:-}" ]; then
  BUILD_ARGS+=(--dart-define="WS_KEY=${WS_KEY}")
fi

flutter "${BUILD_ARGS[@]}"

echo "==> Build complete: frontend/build/web"
