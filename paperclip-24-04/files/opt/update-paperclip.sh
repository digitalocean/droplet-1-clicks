#!/bin/bash
# Update managed Paperclip CLI and restart the service.
#
# Usage:
#   /opt/update-paperclip.sh                 # latest stable
#   /opt/update-paperclip.sh 2026.1117.0      # exact version
#   /opt/update-paperclip.sh v2026.1117.0     # same (v stripped)
#   /opt/update-paperclip.sh --rollback      # previous managed payload

set -euo pipefail

# shellcheck source=/opt/paperclip-safe-file.sh
source /opt/paperclip-safe-file.sh

ENV_FILE=/opt/paperclip.env

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 ${*:-}" >&2
  exit 1
fi

# Keep runtime pins aligned with the image bake defaults from template.json.
export NODE_VERSION="${NODE_VERSION:-24.22.3}"
export OPENCODE_VERSION="${OPENCODE_VERSION:-1.19.6}"
chmod +x /opt/ensure-paperclip-node.sh
/opt/ensure-paperclip-node.sh
chmod +x /opt/ensure-paperclip-opencode.sh
if ! /opt/ensure-paperclip-opencode.sh; then
  echo "WARNING: OpenCode CLI is not installed. OpenCode agent verification cannot pass until /usr/local/bin/opencode exists." >&2
fi

usage() {
  cat <<'EOF'
Usage: /opt/update-paperclip.sh [version|--rollback]

  (no args) / latest   Update to the latest stable managed release
  2026.1117.0          Install that exact published version
  --rollback           Roll back to the previous managed CLI payload

PAPERCLIP_VERSION in /opt/paperclip.env is updated after a successful pin.
EOF
}

read_env_kv() {
  local key="$1" line val
  [ -f "$ENV_FILE" ] || return 1
  line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"
  val="${val%\"}"
  printf '%s' "$val"
}

set_env_kv() {
  local key="$1" value="$2" file="${3:-$ENV_FILE}"
  paperclip_write_env_kv "$file" "$key" "$value"
}

normalize_version() {
  local v="${1#v}"
  case "$v" in
    ''|Latest|LATEST|latest) printf '%s' "latest" ;;
    *) printf '%s' "$v" ;;
  esac
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --rollback|-r)
    MODE="rollback"
    ;;
  *)
    MODE="update"
    TARGET="$(normalize_version "${1:-latest}")"
    ;;
esac

BEFORE="$(read_env_kv PAPERCLIP_VERSION || true)"
echo "Stopping Paperclip..."
systemctl stop paperclip || true

if [ "$MODE" = "rollback" ]; then
  echo "Rolling back managed Paperclip CLI..."
  if ! su - paperclip -c "PATH=/usr/bin:/bin:\$HOME/.local/bin paperclipai update --rollback"; then
    echo "Rollback failed." >&2
    systemctl start paperclip || true
    exit 1
  fi
else
  echo "Updating Paperclip (target: ${TARGET})..."
  if [ "$TARGET" = "latest" ]; then
    UPDATE_CMD="paperclipai update --latest"
  else
    UPDATE_CMD="paperclipai update --version ${TARGET} --yes"
  fi
  if ! su - paperclip -c "PATH=/usr/bin:/bin:\$HOME/.local/bin ${UPDATE_CMD}"; then
    echo "Update failed." >&2
    systemctl start paperclip || true
    exit 1
  fi
fi

RAW_VERSION="$(su - paperclip -c "PATH=/usr/bin:/bin:\$HOME/.local/bin paperclipai --version" 2>/dev/null | head -n 1 || true)"
# Accept calver (YYYY.N.N) or semver (N.N.N); only keep INSTALLED when extraction succeeds
INSTALLED="$(printf '%s' "$RAW_VERSION" | sed -nE 's/.*([0-9]{4}\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
if [ -z "${INSTALLED}" ]; then
  if [ "$MODE" = "update" ] && [ "${TARGET:-}" != "latest" ]; then
    INSTALLED="$TARGET"
  else
    echo "Warning: could not parse paperclipai --version output; leaving PAPERCLIP_VERSION unchanged." >&2
    [ -n "${RAW_VERSION}" ] && echo "  raw: ${RAW_VERSION}" >&2
  fi
fi

if [ -n "${BEFORE}" ] && [ -n "${INSTALLED}" ] && [ "${BEFORE}" != "${INSTALLED}" ]; then
  set_env_kv PAPERCLIP_VERSION_PREVIOUS "$BEFORE"
fi
if [ -n "${INSTALLED}" ]; then
  set_env_kv PAPERCLIP_VERSION "$INSTALLED"
fi

# Merge /opt/paperclip.env into instance .env (preserve instance-only keys).
# Never copy INITIAL_PASSWORD into service EnvironmentFiles (creds stay in
# /root/paperclip_admin_credentials). Migrate any leftover password into the
# creds file before stripping it from EnvironmentFiles.
CREDS_FILE=/root/paperclip_admin_credentials
INSTANCE_ENV=/home/paperclip/.paperclip/instances/default/.env

creds_password_usable() {
  local cval=""
  if [ -f "$CREDS_FILE" ]; then
    cval="$(grep -E '^INITIAL_PASSWORD=' "$CREDS_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
  fi
  case "$cval" in
    ''|PLACEHOLDER*) return 1 ;;
    *) return 0 ;;
  esac
}

ensure_admin_credentials_file() {
  local email password
  email=""
  password=""
  if [ -f "$CREDS_FILE" ]; then
    email="$(grep -E '^ADMIN_EMAIL=' "$CREDS_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
    password="$(grep -E '^INITIAL_PASSWORD=' "$CREDS_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
  fi
  case "$email" in ''|PLACEHOLDER*) email="$(read_env_kv ADMIN_EMAIL || true)" ;; esac
  case "$password" in ''|PLACEHOLDER*) password="$(read_env_kv INITIAL_PASSWORD || true)" ;; esac
  email="${email:-admin@paperclip.local}"
  case "$password" in
    ''|PLACEHOLDER*) return 0 ;;
  esac
  cat > "$CREDS_FILE" <<EOF
ADMIN_EMAIL=${email}
INITIAL_PASSWORD=${password}
EOF
  chmod 600 "$CREDS_FILE"
}

ensure_admin_credentials_file

if [ -e "$INSTANCE_ENV" ] || [ -L "$INSTANCE_ENV" ]; then
  paperclip_assert_safe_target "$INSTANCE_ENV" || exit 1
fi
if [ -f "$INSTANCE_ENV" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
      INITIAL_PASSWORD=*) continue ;;
      *=*)
        set_env_kv "${line%%=*}" "${line#*=}" "$INSTANCE_ENV"
        ;;
    esac
  done <"$ENV_FILE"
  paperclip_remove_env_kv "$INSTANCE_ENV" INITIAL_PASSWORD
fi
# Strip INITIAL_PASSWORD from service env only when root creds already hold it.
if [ -f "$ENV_FILE" ] && creds_password_usable; then
  paperclip_remove_env_kv "$ENV_FILE" INITIAL_PASSWORD
fi

echo "Starting Paperclip..."
systemctl start paperclip
systemctl restart caddy || true
sleep 2
echo "Update complete."
/opt/status-paperclip.sh
if [ -f /opt/paperclip/.provider-configured ] && [ -x /opt/bootstrap-paperclip-do-agent.sh ]; then
  echo "Re-checking DigitalOcean agent hire (idempotent)..."
  /opt/bootstrap-paperclip-do-agent.sh || \
    echo "WARNING: DO agent bootstrap did not complete; run sudo /opt/bootstrap-paperclip-do-agent.sh" >&2
fi
