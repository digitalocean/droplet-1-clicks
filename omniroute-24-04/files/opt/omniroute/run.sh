#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

COMPOSE_FILES=(-f compose.yml)

compose() {
  docker compose --env-file .env "${COMPOSE_FILES[@]}" "$@"
}

require_env() {
  if [[ ! -f .env ]]; then
    echo "Missing /opt/omniroute/.env" >&2
    exit 1
  fi
  if grep -vE '^\s*#' .env | grep -Eq 'PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT|PLACEHOLDER_DOMAIN'; then
    echo "/opt/omniroute/.env still contains placeholders. Wait for first-boot init or finish setup." >&2
    exit 1
  fi
}

case "${1:-help}" in
  start|up)
    require_env
    compose up -d --wait
    ;;
  stop|down)
    compose down
    ;;
  restart)
    require_env
    compose up -d --wait --force-recreate omniroute
    ;;
  pull)
    require_env
    compose pull
    ;;
  upgrade)
    require_env
    compose pull
    compose up -d --wait
    ;;
  logs)
    shift || true
    compose logs -f "${@:-omniroute}"
    ;;
  status|ps)
    compose ps
    ;;
  exec)
    shift || true
    compose exec -T omniroute "$@"
    ;;
  config)
    require_env
    compose config
    ;;
  help|-h|--help)
    cat <<'MSG'
Usage: /opt/omniroute/run.sh <command>

Commands:
  start         Start OmniRoute (docker compose up -d --wait)
  stop          Stop containers (volumes preserved)
  restart       Recreate the omniroute service after env/image changes
  pull          Pull configured images
  upgrade       Pull and restart
  logs [svc]    Follow logs (default: omniroute)
  status        Show compose service status
  exec <cmd…>   Run a command in the omniroute container (e.g. omniroute doctor)
  config        Render merged compose config
MSG
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Run /opt/omniroute/run.sh help" >&2
    exit 1
    ;;
esac
