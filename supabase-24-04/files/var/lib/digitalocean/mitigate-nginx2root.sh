#!/bin/bash
# CVE-2026-123007 mitigation for Supabase self-hosting:
# - Kong: force KONG_*_LISTEN without http2 in docker .env
# - Host templates: http2 removed in supabase_ssl (domain TLS path)
set -euo pipefail

COMPOSE_DIR="${1:-/srv/supabase/supabase/docker}"
ENV_FILE="${COMPOSE_DIR}/.env"

KONG_PROXY_LISTEN='0.0.0.0:8000 reuseport backlog=16384, 0.0.0.0:8443 ssl reuseport backlog=16384'
KONG_ADMIN_LISTEN='127.0.0.1:8001 reuseport backlog=16384, 127.0.0.1:8444 ssl reuseport backlog=16384'

upsert_env() {
  local key="$1"
  local value="$2"
  touch "${ENV_FILE}"
  sed -i "/^${key}=/d" "${ENV_FILE}"
  printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
}

patch_kong_env() {
  if [ ! -f "${ENV_FILE}" ]; then
    echo "ERROR: missing ${ENV_FILE}" >&2
    return 1
  fi
  upsert_env KONG_PROXY_LISTEN "${KONG_PROXY_LISTEN}"
  upsert_env KONG_ADMIN_LISTEN "${KONG_ADMIN_LISTEN}"

  if grep -vE '^[[:space:]]*#' "${ENV_FILE}" | grep -qE '^KONG_(PROXY|ADMIN)_LISTEN=.*http2'; then
    echo "ERROR: ${ENV_FILE} still sets Kong listen with http2" >&2
    return 1
  fi
}

restart_kong_if_running() {
  if docker ps --format '{{.Names}}' | grep -qx supabase-kong; then
    local -a args=(-f docker-compose.yml)
    if [ -f "${COMPOSE_DIR}/docker-compose.dbaas.yml" ]; then
      args+=(-f docker-compose.dbaas.yml)
    fi
    (cd "${COMPOSE_DIR}" && docker compose "${args[@]}" up -d --force-recreate kong)
  fi
}

main() {
  patch_kong_env
  restart_kong_if_running
  echo "mitigate-nginx2root: Kong listen directives patched (HTTP/2 disabled)"
}

main "$@"