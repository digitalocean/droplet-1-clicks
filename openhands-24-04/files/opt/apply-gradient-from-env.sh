#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/openhands.env.
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/openhands.env
OPENHANDS_HOME=/home/openhands
SETTINGS_FILE="${OPENHANDS_HOME}/.openhands/agent_settings.json"
SETUP_DONE_MARKER="${OPENHANDS_HOME}/.openhands/provider-configured"
GRADIENT_BASE_URL="https://inference.do-ai.run/v1"

remove_setup_wizard_bashrc_hook() {
  [ -f /root/.bashrc ] || return 0
  sed -i \
    -e '/chmod +x \/etc\/setup_wizard\.sh/d' \
    -e '/\/etc\/setup_wizard\.sh/d' \
    /root/.bashrc
}

env_value_usable() {
  local v="$1"
  [ -n "$v" ] || return 1
  case "$v" in
    *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
  esac
  return 0
}

read_file_kv() {
  local file="$1" key="$2" line val
  [ -f "$file" ] || return 1
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
  printf '%s' "$val"
}

read_config_value() {
  local key="$1" val
  val="${!key-}"
  if env_value_usable "$val"; then
    printf '%s' "$val"
    return 0
  fi
  val=$(read_file_kv /etc/environment "$key" || true)
  if env_value_usable "$val"; then
    printf '%s' "$val"
    return 0
  fi
  read_file_kv "$ENV_FILE" "$key"
}

write_env_file_kv() {
  local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
  # Plain KEY=value for systemd EnvironmentFile (no shell %q escaping)
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

normalize_model() {
  local m="$1"
  case "$m" in
    openai/*) printf '%s' "$m" ;;
    "") printf '%s' "openai/minimax-m2.5" ;;
    *) printf 'openai/%s' "$m" ;;
  esac
}

GRADIENT_KEY=$(read_config_value GRADIENT_KEY || true)
GRADIENT_MODEL=$(read_config_value GRADIENT_MODEL || true)

if ! env_value_usable "$GRADIENT_KEY"; then
  exit 1
fi

if ! env_value_usable "$GRADIENT_MODEL"; then
  GRADIENT_MODEL="minimax-m2.5"
fi

PRIMARY_MODEL=$(normalize_model "$GRADIENT_MODEL")
write_env_file_kv GRADIENT_KEY "$GRADIENT_KEY"
write_env_file_kv GRADIENT_MODEL "${PRIMARY_MODEL#openai/}"

mkdir -p "${OPENHANDS_HOME}/.openhands"

# Seed agent settings for OpenHands / Agent Canvas (LiteLLM OpenAI-compatible)
jq -n \
  --arg model "$PRIMARY_MODEL" \
  --arg key "$GRADIENT_KEY" \
  --arg base "$GRADIENT_BASE_URL" \
  '{
    llm: {
      model: $model,
      api_key: $key,
      base_url: $base
    }
  }' > "$SETTINGS_FILE"

printf '%s\n' "DigitalOcean Gradient" > "$SETUP_DONE_MARKER"
chown -R openhands:openhands "${OPENHANDS_HOME}/.openhands"
chmod 700 "${OPENHANDS_HOME}/.openhands"
chmod 600 "$SETTINGS_FILE" "$SETUP_DONE_MARKER"

remove_setup_wizard_bashrc_hook

# Restart if already running so settings are picked up
if systemctl is-active --quiet openhands 2>/dev/null; then
  systemctl restart openhands || true
fi

echo "OpenHands configured for DigitalOcean Gradient: ${PRIMARY_MODEL}"
exit 0
