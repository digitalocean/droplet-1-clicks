#!/bin/bash
# Apply DigitalOcean Serverless Inference into Nod's self-host .env.
# Returns 0 when configured; 1 when skipped (no usable MODEL_ACCESS_KEY).
set -euo pipefail

NOD_DIR="${NOD_DIR:-/opt/nod}"
SELF_HOST_DIR="${NOD_DIR}/deployment/self-host"
NOD_ENV_FILE="${SELF_HOST_DIR}/.env"
OPT_ENV_FILE=/opt/nod.env
SETUP_MARKER=/root/.nod_inference_configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
INFERENCE_BASE_URL="${INFERENCE_BASE_URL:-https://inference.do-ai.run/v1}"

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
  read_file_kv "$OPT_ENV_FILE" "$key"
}

write_kv() {
  local file="$1" key="$2" val="$3" tmp
  # Use bash pattern match — `grep` with a newline pattern is treated as an
  # empty pattern by GNU grep and matches every value (false positive).
  case "$val" in
    *$'\n'*)
      echo "ERROR: refusing to write multiline value for ${key}" >&2
      exit 1
      ;;
  esac
  tmp="${file}.tmp"
  touch "$file"
  grep -vE "^${key}=" "$file" >"$tmp" 2>/dev/null || : >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$file"
  chmod 600 "$file"
}

normalize_router_name() {
  local n="$1"
  n="${n#digitalocean/}"
  n="${n#router:}"
  printf '%s' "$n"
}

redact_inference_secrets_from_system_environment() {
  local env_file=/etc/environment
  [ -f "$env_file" ] || return 0
  grep -Ev '^MODEL_ACCESS_KEY=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
  mv "${env_file}.tmp" "$env_file"
  chmod 644 "$env_file"
}

finish_apply() {
  local message="$1"
  redact_inference_secrets_from_system_environment
  touch "$SETUP_MARKER"
  chmod 600 "$SETUP_MARKER"
  remove_setup_wizard_bashrc_hook
  echo "$message"
  exit 0
}

MODEL_ACCESS_KEY=$(read_config_value MODEL_ACCESS_KEY || true)
INFERENCE_MODEL=$(read_config_value INFERENCE_MODEL || true)
DO_INFERENCE_ROUTER=$(read_config_value DO_INFERENCE_ROUTER || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
  exit 1
fi

if [ ! -f "$NOD_ENV_FILE" ]; then
  echo "ERROR: missing ${NOD_ENV_FILE}; finish first-boot Nod setup first." >&2
  exit 1
fi

CHAT_IDS=""
if [ -f "$INFERENCE_MODELS_LIB" ]; then
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"
  CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY" || true)"
fi

SELECTED_MODEL=""
ROUTER_NAME=""

if env_value_usable "$DO_INFERENCE_ROUTER"; then
  ROUTER_NAME=$(normalize_router_name "$DO_INFERENCE_ROUTER")
  if [ -n "$ROUTER_NAME" ]; then
    SELECTED_MODEL="router:${ROUTER_NAME}"
  fi
elif env_value_usable "$INFERENCE_MODEL"; then
  case "$INFERENCE_MODEL" in
    router:*)
      SELECTED_MODEL="$INFERENCE_MODEL"
      ROUTER_NAME=$(normalize_router_name "$INFERENCE_MODEL")
      ;;
    digitalocean/*)
      SELECTED_MODEL="${INFERENCE_MODEL#digitalocean/}"
      ;;
    *)
      SELECTED_MODEL="$INFERENCE_MODEL"
      ;;
  esac
else
  if [ -z "$CHAT_IDS" ]; then
    echo "Could not list Serverless Inference models and no INFERENCE_MODEL was set." >&2
    exit 1
  fi
  SELECTED_MODEL="$(printf '%s\n' "$CHAT_IDS" | pick_default_inference_model)"
fi

write_kv "$OPT_ENV_FILE" MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
write_kv "$OPT_ENV_FILE" INFERENCE_MODEL "$SELECTED_MODEL"
write_kv "$OPT_ENV_FILE" DO_INFERENCE_ROUTER "${ROUTER_NAME}"

# Nod OpenAI-compatible provider → DigitalOcean Serverless Inference.
write_kv "$NOD_ENV_FILE" LLM_PROVIDER "compatible"
write_kv "$NOD_ENV_FILE" OPENAI_COMPATIBLE_BASE_URL "$INFERENCE_BASE_URL"
write_kv "$NOD_ENV_FILE" OPENAI_COMPATIBLE_API_KEY "$MODEL_ACCESS_KEY"
write_kv "$NOD_ENV_FILE" LLM_MODEL "$SELECTED_MODEL"

if systemctl is-active --quiet nod.service 2>/dev/null; then
  /opt/restart-nod.sh || true
fi

finish_apply "DigitalOcean Serverless Inference configured for Nod: ${SELECTED_MODEL} via ${INFERENCE_BASE_URL}"
