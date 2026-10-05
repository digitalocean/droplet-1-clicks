#!/bin/bash
# Update managed Paperclip CLI and restart the service.
#
# Usage:
#   /opt/update-paperclip.sh                 # latest stable
#   /opt/update-paperclip.sh 2026.916.1      # exact version
#   /opt/update-paperclip.sh v2026.916.1     # same (v stripped)
#   /opt/update-paperclip.sh --rollback      # previous managed payload

set -euo pipefail

ENV_FILE=/opt/paperclip.env

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 ${*:-}" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: /opt/update-paperclip.sh [version|--rollback]

  (no args) / latest   Update to the latest stable managed release
  2026.916.1           Install that exact published version
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
  local key="$1" value="$2" file="${3:-$ENV_FILE}" tmp
  touch "$file"
  tmp="$(mktemp)"
  # Avoid sed replacements: values may contain & \ | etc.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$file" >"$tmp"
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$file"
  chmod 600 "$file"
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
  if ! su - paperclip -c "paperclipai update --rollback"; then
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
  if ! su - paperclip -c "$UPDATE_CMD"; then
    echo "Update failed." >&2
    systemctl start paperclip || true
    exit 1
  fi
fi

RAW_VERSION="$(su - paperclip -c "paperclipai --version" 2>/dev/null | head -n 1 || true)"
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

# Merge /opt/paperclip.env into instance .env (preserve instance-only keys)
INSTANCE_ENV=/home/paperclip/.paperclip/instances/default/.env
if [ -f "$INSTANCE_ENV" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
      *=*)
        set_env_kv "${line%%=*}" "${line#*=}" "$INSTANCE_ENV"
        ;;
    esac
  done <"$ENV_FILE"
  chown paperclip:paperclip "$INSTANCE_ENV"
  chmod 600 "$INSTANCE_ENV"
fi

echo "Starting Paperclip..."
systemctl start paperclip
systemctl restart caddy || true
sleep 2
echo "Update complete."
/opt/status-paperclip.sh
