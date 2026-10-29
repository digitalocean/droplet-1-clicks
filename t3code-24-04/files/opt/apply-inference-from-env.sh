#!/bin/bash
# Apply DigitalOcean Serverless Inference as its own Claude provider instance.
# Reads MODEL_ACCESS_KEY, optional INFERENCE_MODEL, and optional DO_INFERENCE_ROUTER
# from the environment, /etc/environment, or /opt/t3code-inference.env.
# The key stays on that instance only. systemd does not load /opt/t3code-inference.env,
# and the key is stripped from /opt/t3code.env. Claude Code reads it with apiKeyHelper
# (printenv MODEL_ACCESS_KEY). ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are not set.
# Returns 0 when a key was applied; 1 when skipped.
set -euo pipefail

ENV_FILE=/opt/t3code-inference.env
SERVICE_ENV=/opt/t3code.env
T3_HOME=/home/t3/.t3
SETTINGS_FILE="${T3_HOME}/userdata/settings.json"
SETTINGS_TEMPLATE=/opt/t3code-settings.json
CLAUDE_DIR=/home/t3/.claude-digitalocean
MARKER="${T3_HOME}/inference-configured"
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
INFERENCE_BASE_URL=https://inference.do-ai.run
DEFAULT_MODEL=anthropic-claude-4.6-sonnet

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
    *'${'*|PLACEHOLDER*|your_*_here|*$'\n'*) return 1 ;;
  esac
  return 0
}

read_file_kv() {
  local file="$1" key="$2" line val
  [ -f "$file" ] || return 1
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"; val="${val%\"}"
  val="${val#\'}"; val="${val%\'}"
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
  val=$(read_file_kv "$ENV_FILE" "$key" || true)
  if env_value_usable "$val"; then
    printf '%s' "$val"
    return 0
  fi
  read_file_kv "$SERVICE_ENV" "$key"
}

write_env_file_kv() {
  local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

strip_inference_keys() {
  # Split locals: with set -u, bash expands ${env_file} before local assigns it
  # when declared on the same line as tmp="${env_file}.tmp".
  local env_file="$1"
  local mode="$2"
  local tmp="${env_file}.tmp"
  [ -f "$env_file" ] || return 0
  grep -Ev '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$env_file" >"$tmp" 2>/dev/null || : >"$tmp"
  mv "$tmp" "$env_file"
  chmod "$mode" "$env_file"
}

redact_inference_secrets_from_system_environment() {
  strip_inference_keys /etc/environment 644
  strip_inference_keys "$SERVICE_ENV" 600
}

choose_default_model() {
  local ids="$1" preferred
  preferred=$(printf '%s\n' "$ids" | grep -E '^(anthropic-claude|claude)' | head -n 1 || true)
  if [ -n "$preferred" ]; then
    printf '%s' "$preferred"
    return 0
  fi
  printf '%s\n' "$ids" | pick_default_inference_model
}

MODEL_ACCESS_KEY=$(read_config_value MODEL_ACCESS_KEY || true)
INFERENCE_MODEL=$(read_config_value INFERENCE_MODEL || true)
DO_INFERENCE_ROUTER=$(read_config_value DO_INFERENCE_ROUTER || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
  exit 1
fi

CHAT_IDS=""
if [ -f "$INFERENCE_MODELS_LIB" ]; then
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"
  CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY" || true)"
fi

ROUTER_NAME=""
if env_value_usable "$DO_INFERENCE_ROUTER"; then
  ROUTER_NAME="${DO_INFERENCE_ROUTER#openai/}"
  ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
  ROUTER_NAME="${ROUTER_NAME#router:}"
fi

if [ -n "$ROUTER_NAME" ]; then
  if ! env_value_usable "$INFERENCE_MODEL"; then
    if [ -n "$CHAT_IDS" ]; then
      INFERENCE_MODEL="$(choose_default_model "$CHAT_IDS" || true)"
    fi
    if ! env_value_usable "$INFERENCE_MODEL"; then
      INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
  fi
  PRIMARY_MODEL="router:${ROUTER_NAME}"
else
  if ! env_value_usable "$INFERENCE_MODEL"; then
    if [ -n "$CHAT_IDS" ]; then
      INFERENCE_MODEL="$(choose_default_model "$CHAT_IDS" || true)"
    fi
    if ! env_value_usable "$INFERENCE_MODEL"; then
      INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
  fi
  INFERENCE_MODEL="${INFERENCE_MODEL#openai/}"
  INFERENCE_MODEL="${INFERENCE_MODEL#digitalocean/}"
  PRIMARY_MODEL="$INFERENCE_MODEL"
  ROUTER_NAME=""
fi

write_env_file_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
write_env_file_kv INFERENCE_MODEL "${INFERENCE_MODEL#openai/}"
write_env_file_kv DO_INFERENCE_ROUTER "$ROUTER_NAME"
redact_inference_secrets_from_system_environment

mkdir -p "$CLAUDE_DIR" "${T3_HOME}/userdata"
if [ ! -f "$SETTINGS_FILE" ] && [ -f "$SETTINGS_TEMPLATE" ]; then
  cp "$SETTINGS_TEMPLATE" "$SETTINGS_FILE"
fi
if [ ! -f "$SETTINGS_FILE" ]; then
  printf '%s\n' '{"providerInstances":{}}' > "$SETTINGS_FILE"
fi

jq -n \
  --arg base "$INFERENCE_BASE_URL" \
  --arg model "$PRIMARY_MODEL" \
  '{
    "$schema": "https://json.schemastore.org/claude-code-settings.json",
    apiKeyHelper: "printenv MODEL_ACCESS_KEY",
    env: {
      ANTHROPIC_BASE_URL: $base,
      CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS: "1"
    },
    model: $model,
    availableModels: [$model],
    forceLoginMethod: "console"
  }' > "${CLAUDE_DIR}/settings.json"

jq \
  --arg model "$PRIMARY_MODEL" \
  --arg key "$MODEL_ACCESS_KEY" \
  --arg base "$INFERENCE_BASE_URL" \
  --arg home "$CLAUDE_DIR" \
  '
  .providerInstances["digitalocean-inference"] = {
    driver: "claudeAgent",
    displayName: "DigitalOcean Inference",
    enabled: true,
    environment: [
      {name: "ANTHROPIC_BASE_URL", value: $base, sensitive: false},
      {name: "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS", value: "1", sensitive: false},
      {name: "MODEL_ACCESS_KEY", value: $key, sensitive: true}
    ],
    config: {
      binaryPath: "/usr/local/bin/claude",
      homePath: $home,
      customModels: [$model],
      enabled: true,
      launchArgs: ""
    }
  }
  ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

touch "$MARKER"
chown -R t3:t3 "$T3_HOME" "$CLAUDE_DIR"
chmod 700 "$T3_HOME" "$CLAUDE_DIR" "${T3_HOME}/userdata"
chmod 600 "$SETTINGS_FILE" "${CLAUDE_DIR}/settings.json" "$MARKER"

remove_setup_wizard_bashrc_hook

if systemctl is-active --quiet t3code 2>/dev/null; then
  systemctl restart t3code || true
fi

echo "DigitalOcean Serverless Inference configured: ${PRIMARY_MODEL}"
exit 0
