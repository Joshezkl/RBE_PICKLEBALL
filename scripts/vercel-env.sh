#!/usr/bin/env bash
# Normalize DB env vars for Laravel artisan during Vercel install/build.
set -euo pipefail

trim() {
  local value="${1:-}"
  value="${value//$'\r'/}"
  value="${value//$'\n'/}"
  value="$(echo -n "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//')"
  printf '%s' "$value"
}

if [ -n "${TIDB_HOST:-}" ] && [ -z "${DB_HOST:-}" ]; then export DB_HOST="$(trim "$TIDB_HOST")"; fi
if [ -n "${TIDB_PORT:-}" ] && [ -z "${DB_PORT:-}" ]; then export DB_PORT="$(trim "$TIDB_PORT")"; fi
if [ -n "${TIDB_USER:-}" ] && [ -z "${DB_USERNAME:-}" ]; then export DB_USERNAME="$(trim "$TIDB_USER")"; fi
if [ -n "${TIDB_PASSWORD:-}" ] && [ -z "${DB_PASSWORD:-}" ]; then export DB_PASSWORD="$(trim "$TIDB_PASSWORD")"; fi
if [ -n "${TIDB_DATABASE:-}" ] && [ -z "${DB_DATABASE:-}" ]; then export DB_DATABASE="$(trim "$TIDB_DATABASE")"; fi

export DB_CONNECTION="$(trim "${DB_CONNECTION:-mysql}" | tr '[:upper:]' '[:lower:]')"
export DB_HOST="$(trim "${DB_HOST:-}")"
export DB_PORT="$(trim "${DB_PORT:-}")"
export DB_DATABASE="$(trim "${DB_DATABASE:-}")"
export DB_USERNAME="$(trim "${DB_USERNAME:-}")"
export DB_PASSWORD="$(trim "${DB_PASSWORD:-}")"

if [ -z "${DB_PORT}" ]; then
  if [[ "${DB_HOST}" == *tidbcloud.com* ]]; then
    export DB_PORT="4000"
  else
    export DB_PORT="3306"
  fi
fi

if [ -z "${DB_HOST}" ] && [ -n "${DATABASE_URL:-}" ]; then
  # Minimal mysql://user:pass@host:port/db parser for build-time migrations.
  if [[ "${DATABASE_URL}" =~ mysql://([^:@/]+):([^@/]*)@([^:/]+):?([0-9]*)/([^?]+) ]]; then
    export DB_USERNAME="${BASH_REMATCH[1]}"
    export DB_PASSWORD="${BASH_REMATCH[2]}"
    export DB_HOST="${BASH_REMATCH[3]}"
    if [ -n "${BASH_REMATCH[4]}" ]; then export DB_PORT="${BASH_REMATCH[4]}"; fi
    export DB_DATABASE="${BASH_REMATCH[5]}"
    export DB_CONNECTION="mysql"
  fi
fi

if [[ "${DB_HOST}" == *:* ]]; then
  host_part="${DB_HOST%%:*}"
  port_part="${DB_HOST##*:}"
  export DB_HOST="$host_part"
  if [ -z "${DB_PORT}" ] || [ "${DB_PORT}" = "4000" ]; then
    export DB_PORT="$port_part"
  fi
fi

if [[ "${DB_HOST}" == *tidbcloud.com* ]]; then
  export MYSQL_ATTR_SSL_VERIFY_SERVER_CERT="${MYSQL_ATTR_SSL_VERIFY_SERVER_CERT:-false}"
  if [ -z "${MYSQL_ATTR_SSL_CA:-}" ]; then
    for ca in /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt; do
      if [ -f "$ca" ]; then
        export MYSQL_ATTR_SSL_CA="$ca"
        break
      fi
    done
  fi
fi
