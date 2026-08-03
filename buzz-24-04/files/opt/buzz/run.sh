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
    echo "Missing /opt/buzz/.env" >&2
    exit 1
  fi
  # Ignore comments — Packer/docs lines must not trip this check.
  if grep -vE '^\s*#' .env | grep -Eq 'PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT|PLACEHOLDER_DOMAIN|CHANGE_ME'; then
    echo "/opt/buzz/.env still contains placeholders. Wait for first-boot init or finish setup." >&2
    exit 1
  fi
}

backup_hint() {
  cat <<'MSG'
Back up these before upgrades and on a regular schedule:

- /opt/buzz/.env (BUZZ_RELAY_PRIVATE_KEY, DB/Redis/S3 secrets, BUZZ_GIT_HOOK_HMAC_SECRET)
- /root/buzz_credentials.txt (owner secret key for RELAY_OWNER_PUBKEY)
- Postgres data volume (buzz-postgres-data)
- MinIO/S3 bucket contents (media + git objects)
- buzz-git-data volume

Keep Postgres + object/git state snapshots from the same maintenance window.
MSG
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
    compose up -d --wait --force-recreate relay
    ;;
  pull)
    require_env
    compose pull
    ;;
  upgrade)
    require_env
    compose pull
    compose up -d --wait
    backup_hint
    ;;
  logs)
    shift || true
    compose logs -f "${@:-relay}"
    ;;
  status|ps)
    compose ps
    ;;
  config)
    require_env
    compose config
    ;;
  backup-hint)
    backup_hint
    ;;
  add-member)
    compose exec relay /usr/local/bin/buzz-admin add-member --pubkey "${2:?Usage: ./run.sh add-member <npub-or-hex> [--role member|admin]}" "${@:3}"
    ;;
  remove-member)
    compose exec relay /usr/local/bin/buzz-admin remove-member --pubkey "${2:?Usage: ./run.sh remove-member <npub-or-hex> [--role member|admin]}" "${@:3}"
    ;;
  list-members)
    compose exec relay /usr/local/bin/buzz-admin list-members
    ;;
  help|-h|--help)
    cat <<'MSG'
Usage: /opt/buzz/run.sh <command>

Commands:
  start         Start Buzz (docker compose up -d --wait)
  stop          Stop containers (volumes preserved)
  restart       Recreate the relay after env/image changes
  pull          Pull configured images
  upgrade       Pull and restart, then print backup reminders
  logs [svc]    Follow logs (default: relay)
  status        Show compose service status
  config        Render merged compose config
  backup-hint   Print the production backup checklist

  add-member <npub-or-hex> [--role member|admin]
  remove-member <npub-or-hex> [--role member|admin]
  list-members
MSG
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Run /opt/buzz/run.sh help" >&2
    exit 1
    ;;
esac
