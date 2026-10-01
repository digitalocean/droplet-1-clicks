#!/bin/bash
# Apply DigitalOcean Serverless Inference from droplet env or /opt/paperclip.env
# (MODEL_ACCESS_KEY, INFERENCE_MODEL, DO_INFERENCE_ROUTER).
# Stages keys for OpenAI-compatible adapters; connect providers in the UI after.
# Returns 0 when a key was applied; 1 when skipped.
set -euo pipefail

ENV_FILE=/opt/paperclip.env
INSTANCE_ENV=/home/paperclip/.paperclip/instances/default/.env
SETUP_MARKER=/opt/paperclip/.provider-configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
INFERENCE_BASE_URL="https://inference.do-ai.run/v1"
DEFAULT_MODEL=minimax-m2.5

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
  read_file_kv "$ENV_FILE" "$key"
}

write_env_file_kv() {
  local file="$1" key="$2" val="$3" tmp
  touch "$file"
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
  chmod 600 "$file"
}

# Accept "my-router", "router:my-router", or "digitalocean/router:my-router".
normalize_router_name() {
  local n="$1"
  n="${n#digitalocean/}"
  n="${n#openai/}"
  n="${n#router:}"
  printf '%s' "$n"
}

# /etc/environment is world-readable — strip staged LLM secrets after they land in /opt/paperclip.env
redact_inference_secrets_from_system_environment() {
  local env_file=/etc/environment tmp
  [ -f "$env_file" ] || return 0
  tmp="$(mktemp)"
  grep -Ev '^(MODEL_ACCESS_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|OPENROUTER_API_KEY)=' \
    "$env_file" >"$tmp" 2>/dev/null || : >"$tmp"
  mv "$tmp" "$env_file"
  chmod 644 "$env_file"
}

# Only map DO key onto OPENAI_* when OpenAI is unset, or already points at DO.
# Never set OPENAI_BASE_URL alone while leaving a distinct OpenAI API key in place.
maybe_set_openai_compat_env() {
  local file="$1"
  local existing_key
  existing_key="$(read_file_kv "$file" OPENAI_API_KEY || true)"

  if ! env_value_usable "$existing_key" || [ "$existing_key" = "$MODEL_ACCESS_KEY" ]; then
    write_env_file_kv "$file" OPENAI_API_KEY "$MODEL_ACCESS_KEY"
    write_env_file_kv "$file" OPENAI_BASE_URL "$INFERENCE_BASE_URL"
  else
    echo "Keeping existing OPENAI_API_KEY / OPENAI_BASE_URL; MODEL_ACCESS_KEY stored separately." >&2
  fi
}

sync_instance_env() {
  if [ -f "$INSTANCE_ENV" ]; then
    write_env_file_kv "$INSTANCE_ENV" MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
    write_env_file_kv "$INSTANCE_ENV" INFERENCE_MODEL "$INFERENCE_MODEL"
    write_env_file_kv "$INSTANCE_ENV" DO_INFERENCE_ROUTER "${DO_INFERENCE_ROUTER:-}"
    maybe_set_openai_compat_env "$INSTANCE_ENV"
    chown paperclip:paperclip "$INSTANCE_ENV"
    chmod 600 "$INSTANCE_ENV"
  fi
}

MODEL_ACCESS_KEY=$(read_config_value MODEL_ACCESS_KEY || true)
INFERENCE_MODEL=$(read_config_value INFERENCE_MODEL || true)
DO_INFERENCE_ROUTER=$(read_config_value DO_INFERENCE_ROUTER || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
  exit 1
fi

write_env_file_kv "$ENV_FILE" MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
maybe_set_openai_compat_env "$ENV_FILE"

PRIMARY_MODEL=""
if env_value_usable "$DO_INFERENCE_ROUTER"; then
  ROUTER_NAME=$(normalize_router_name "$DO_INFERENCE_ROUTER")
  if [ -n "$ROUTER_NAME" ]; then
    PRIMARY_MODEL="router:${ROUTER_NAME}"
    if ! env_value_usable "$INFERENCE_MODEL"; then
      INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
    write_env_file_kv "$ENV_FILE" INFERENCE_MODEL "$INFERENCE_MODEL"
    write_env_file_kv "$ENV_FILE" DO_INFERENCE_ROUTER "$ROUTER_NAME"
    DO_INFERENCE_ROUTER="$ROUTER_NAME"
  fi
fi

CHAT_IDS=""
if [ -f "$INFERENCE_MODELS_LIB" ]; then
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"
  CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY" || true)"
fi

if [ -z "${PRIMARY_MODEL:-}" ]; then
  if ! env_value_usable "$INFERENCE_MODEL"; then
    if [ -n "$CHAT_IDS" ]; then
      INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | pick_default_inference_model || true)"
    fi
    if ! env_value_usable "$INFERENCE_MODEL"; then
      INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
  fi
  PRIMARY_MODEL="$INFERENCE_MODEL"
  write_env_file_kv "$ENV_FILE" INFERENCE_MODEL "$PRIMARY_MODEL"
  write_env_file_kv "$ENV_FILE" DO_INFERENCE_ROUTER ""
  DO_INFERENCE_ROUTER=""
  INFERENCE_MODEL="$PRIMARY_MODEL"
fi

sync_instance_env

mkdir -p /opt/paperclip
printf '%s\n' "digitalocean" > "$SETUP_MARKER"
chmod 600 "$SETUP_MARKER"

# Cache model ids for MOTD (same list the wizard shows)
if [ -n "$CHAT_IDS" ]; then
  printf '%s\n' "$CHAT_IDS" > /opt/paperclip/available-models.txt
  chmod 644 /opt/paperclip/available-models.txt
fi

remove_setup_wizard_bashrc_hook
redact_inference_secrets_from_system_environment

if systemctl is-active --quiet paperclip 2>/dev/null; then
  systemctl restart paperclip || true
fi

echo "Testing connection to DigitalOcean Serverless Inference..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${MODEL_ACCESS_KEY}" \
  -H "Content-Type: application/json" \
  "${INFERENCE_BASE_URL}/models" 2>/dev/null || true)

echo "DigitalOcean Serverless Inference staged: model ${PRIMARY_MODEL}"
echo "  Key in /opt/paperclip.env; connect OpenAI-compatible / provider apps in the Paperclip UI."
if [ "$HTTP_STATUS" != "200" ]; then
  echo "Warning: Received HTTP ${HTTP_STATUS:-000} from the Serverless Inference API." >&2
fi

exit 0
