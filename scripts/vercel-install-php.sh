#!/usr/bin/env bash
# Install PHP CLI on Vercel build images (Amazon Linux) for composer/migrations.
set -euo pipefail

if command -v php >/dev/null 2>&1; then
  php -v
  exit 0
fi

echo "==> PHP not found — installing for build"

if command -v dnf >/dev/null 2>&1; then
  dnf install -y \
    php \
    php-cli \
    php-mbstring \
    php-xml \
    php-pdo \
    php-mysqlnd \
    php-json \
    php-tokenizer \
    php-curl \
    php-zip \
    php-opcache \
    2>/dev/null && command -v php >/dev/null 2>&1 && php -v && exit 0

  dnf install -y php8.2 php8.2-cli php8.2-mbstring php8.2-xml php8.2-mysqlnd 2>/dev/null \
    && command -v php >/dev/null 2>&1 && php -v && exit 0
fi

if command -v yum >/dev/null 2>&1; then
  yum install -y php php-cli php-mbstring php-xml php-mysqlnd php-json php-tokenizer php-curl php-zip \
    2>/dev/null && command -v php >/dev/null 2>&1 && php -v && exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y php-cli php-mbstring php-xml php-mysql php-curl php-zip php-tokenizer \
    2>/dev/null && command -v php >/dev/null 2>&1 && php -v && exit 0
fi

echo "==> Trying Heroku PHP buildpack tarball fallback"
ROOT="${VERCEL_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PHP_DIR="${HOME}/.vercel-php"
mkdir -p "$PHP_DIR"
PHP_VERSION="${PHP_BUILD_VERSION:-8.2.28}"
TARBALL="heroku-php-${PHP_VERSION}.tar.gz"
URL="https://heroku-php.s3.us-east-1.amazonaws.com/heroku/php/${TARBALL}"
if curl -fsSL "$URL" -o "/tmp/${TARBALL}"; then
  tar -xzf "/tmp/${TARBALL}" -C "$PHP_DIR" --strip-components=1 2>/dev/null || tar -xzf "/tmp/${TARBALL}" -C "$PHP_DIR"
  if [ -d "$PHP_DIR/usr/bin" ]; then
    echo "export PATH=\"$PHP_DIR/usr/bin:\$PATH\"" > "$ROOT/.vercel-php-path.sh"
  elif [ -d "$PHP_DIR/bin" ]; then
    echo "export PATH=\"$PHP_DIR/bin:\$PATH\"" > "$ROOT/.vercel-php-path.sh"
  fi
  if [ -f "$ROOT/.vercel-php-path.sh" ]; then
    # shellcheck disable=SC1090
    source "$ROOT/.vercel-php-path.sh"
  fi
  if command -v php >/dev/null 2>&1; then
    php -v
    exit 0
  fi
fi

echo "ERROR: Could not install PHP on this build image." >&2
exit 1
