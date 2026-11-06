#!/bin/bash
# Write Paperclip instance config for authenticated/public behind Caddy (loopback).
# Also provision secrets artifacts that `paperclipai onboard` normally creates
# (master key + PAPERCLIP_AGENT_JWT_SECRET) so `paperclipai run` / doctor succeed.
#
# authenticated/public requires Postgres via DATABASE_URL / connectionString
# (embedded PostgreSQL is refused for that deployment contract).
#
# auth.disableSignUp must stay false until the bootstrap invite creates the first
# admin: Better Auth's disableSignUp blocks all email signup, including InviteLanding
# signUpEmail for bootstrap_ceo (paperclipai#5312). Operators can set it true after claim.
set -euo pipefail

PUBLIC_URL="${1:-}"
ALLOWED_HOSTNAME="${2:-}"
DATABASE_URL="${3:-}"

if [ -z "$PUBLIC_URL" ] || [ -z "$ALLOWED_HOSTNAME" ]; then
  echo "Usage: $0 <public-url> <allowed-hostname> [database-url]" >&2
  exit 1
fi

read_env_kv() {
  local key="$1" file="$2" line val
  [ -f "$file" ] || return 1
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"
  val="${val%\"}"
  printf '%s' "$val"
}

if [ -z "$DATABASE_URL" ]; then
  DATABASE_URL="$(read_env_kv DATABASE_URL /opt/paperclip.env 2>/dev/null || true)"
fi
if [ -z "$DATABASE_URL" ] || [[ "$DATABASE_URL" == *PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT* ]]; then
  echo "ERROR: DATABASE_URL must be a real postgres:// connection string (authenticated/public rejects embedded Postgres)." >&2
  exit 1
fi

# Escape for JSON string value (includes surrounding quotes)
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

INSTANCE_ROOT=/home/paperclip/.paperclip/instances/default
CONFIG_PATH="${INSTANCE_ROOT}/config.json"
ENV_PATH="${INSTANCE_ROOT}/.env"
SECRETS_KEY_PATH="${INSTANCE_ROOT}/secrets/master.key"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

DATABASE_URL_JSON="$(json_escape "$DATABASE_URL")"
PUBLIC_URL_JSON="$(json_escape "$PUBLIC_URL")"
ALLOWED_HOSTNAME_JSON="$(json_escape "$ALLOWED_HOSTNAME")"
LOG_DIR_JSON="$(json_escape "${INSTANCE_ROOT}/logs")"
BACKUP_DIR_JSON="$(json_escape "${INSTANCE_ROOT}/data/backups")"
STORAGE_DIR_JSON="$(json_escape "${INSTANCE_ROOT}/data/storage")"
SECRETS_KEY_JSON="$(json_escape "$SECRETS_KEY_PATH")"
NOW_JSON="$(json_escape "$NOW")"

mkdir -p \
  "${INSTANCE_ROOT}/logs" \
  "${INSTANCE_ROOT}/data/storage" \
  "${INSTANCE_ROOT}/data/backups" \
  "${INSTANCE_ROOT}/secrets"

cat > "$CONFIG_PATH" <<EOF
{
  "\$meta": {
    "version": 1,
    "updatedAt": ${NOW_JSON},
    "source": "onboard"
  },
  "database": {
    "mode": "postgres",
    "connectionString": ${DATABASE_URL_JSON},
    "backup": {
      "enabled": true,
      "intervalMinutes": 60,
      "retentionDays": 30,
      "dir": ${BACKUP_DIR_JSON}
    }
  },
  "logging": {
    "mode": "file",
    "logDir": ${LOG_DIR_JSON}
  },
  "server": {
    "deploymentMode": "authenticated",
    "exposure": "public",
    "bind": "loopback",
    "host": "127.0.0.1",
    "port": 3100,
    "allowedHostnames": [${ALLOWED_HOSTNAME_JSON}],
    "serveUi": true
  },
  "auth": {
    "baseUrlMode": "explicit",
    "disableSignUp": false,
    "publicBaseUrl": ${PUBLIC_URL_JSON}
  },
  "storage": {
    "provider": "local_disk",
    "localDisk": {
      "baseDir": ${STORAGE_DIR_JSON}
    },
    "s3": {
      "bucket": "paperclip",
      "region": "us-east-1",
      "prefix": "",
      "forcePathStyle": false
    }
  },
  "secrets": {
    "provider": "local_encrypted",
    "strictMode": false,
    "localEncrypted": {
      "keyFilePath": ${SECRETS_KEY_JSON}
    }
  },
  "telemetry": {
    "enabled": true
  },
  "updates": {
    "checkEnabled": true
  }
}
EOF

# Mirror marketplace env into the instance .env (loaded by paperclipai / systemd)
if [ -f /opt/paperclip.env ]; then
  cp /opt/paperclip.env "$ENV_PATH"
else
  touch "$ENV_PATH"
fi

ensure_env_kv() {
  local key="$1" val="$2" file="$3" tmp cur
  touch "$file"
  cur=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) cur="${line#${key}=}" ;;
    esac
  done <"$file"
  # Keep existing non-empty / non-placeholder values
  if [ -n "$cur" ] && [ "$cur" != "PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT" ] && [[ "$cur" != *PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT* ]]; then
    return 0
  fi
  tmp="$(mktemp)"
  # Avoid sed replacements: values may contain & \ | etc.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$file" >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$file"
}

ensure_env_kv DATABASE_URL "$DATABASE_URL" "$ENV_PATH"
ensure_env_kv PAPERCLIP_AUTH_DISABLE_SIGN_UP false "$ENV_PATH"
if [ -f /opt/paperclip.env ]; then
  ensure_env_kv DATABASE_URL "$DATABASE_URL" /opt/paperclip.env
  ensure_env_kv PAPERCLIP_AUTH_DISABLE_SIGN_UP false /opt/paperclip.env
fi

# Local-encrypted secrets key (required by paperclipai doctor / run)
if [ ! -s "$SECRETS_KEY_PATH" ]; then
  openssl rand -base64 32 >"$SECRETS_KEY_PATH"
fi
chmod 600 "$SECRETS_KEY_PATH"

# Agent JWT secret expected beside config.json
if ! grep -q '^PAPERCLIP_AGENT_JWT_SECRET=.\+' "$ENV_PATH" 2>/dev/null; then
  ensure_env_kv PAPERCLIP_AGENT_JWT_SECRET "$(openssl rand -hex 32)" "$ENV_PATH"
fi
if [ -f /opt/paperclip.env ]; then
  if ! grep -q '^PAPERCLIP_AGENT_JWT_SECRET=.\+' /opt/paperclip.env 2>/dev/null; then
    ensure_env_kv PAPERCLIP_AGENT_JWT_SECRET "$(sed -n 's/^PAPERCLIP_AGENT_JWT_SECRET=//p' "$ENV_PATH" | tail -n 1)" /opt/paperclip.env
  fi
fi

chown -R paperclip:paperclip /home/paperclip/.paperclip
chmod 700 /home/paperclip/.paperclip
chmod 700 "$INSTANCE_ROOT"
chmod 600 "$CONFIG_PATH"
chmod 600 "$ENV_PATH" 2>/dev/null || true
chmod 600 "$SECRETS_KEY_PATH"

echo "Wrote Paperclip config to ${CONFIG_PATH}"
echo "Database: postgres (local) via DATABASE_URL"
echo "Secrets key: ${SECRETS_KEY_PATH}"
