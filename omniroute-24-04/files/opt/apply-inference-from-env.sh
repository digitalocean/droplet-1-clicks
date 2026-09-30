#!/bin/bash
# Apply DigitalOcean Serverless Inference from droplet env or /opt/omniroute/.env
# (MODEL_ACCESS_KEY, INFERENCE_MODEL, DO_INFERENCE_ROUTER).
# Adds/updates the OmniRoute `digitalocean` provider via the running HTTP API
# (published Docker images do not ship an `omniroute` CLI on PATH).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/omniroute/.env
SETUP_MARKER=/opt/omniroute/.provider-configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
OMNIROUTE_INFERENCE_HELPERS=/opt/omniroute/inference-helpers.sh
DEFAULT_MODEL=minimax-m2.5
OMNIROUTE_API="${OMNIROUTE_API:-http://127.0.0.1:20128}"

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
  local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

redact_inference_secrets_from_system_environment() {
  local env_file=/etc/environment
  [ -f "$env_file" ] || return 0
  grep -Ev '^MODEL_ACCESS_KEY=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
  mv "${env_file}.tmp" "$env_file"
  chmod 644 "$env_file"
}

# Accept "my-router", "router:my-router", or "digitalocean/router:my-router".
normalize_router_name() {
  local n="$1"
  n="${n#digitalocean/}"
  n="${n#openai/}"
  n="${n#router:}"
  printf '%s' "$n"
}

wait_for_omniroute() {
  local i
  for i in $(seq 1 90); do
    if curl -fsS --max-time 2 "${OMNIROUTE_API}/" >/dev/null 2>&1 \
      || curl -fsS --max-time 2 "${OMNIROUTE_API}/api/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "OmniRoute is not ready at ${OMNIROUTE_API}." >&2
  return 1
}

# Login with INITIAL_PASSWORD; return the dashboard session JWT.
# Management routes authenticate via Cookie auth_token (dashboard session).
# Do NOT send that JWT as Authorization: Bearer — that path expects manage-scoped
# API keys / oma_ tokens and returns AUTH_001 "Invalid management token".
omniroute_login_token() {
  local password jar token
  password="$(read_config_value INITIAL_PASSWORD || true)"
  if ! env_value_usable "$password"; then
    echo "INITIAL_PASSWORD is not set; cannot authenticate to OmniRoute API." >&2
    return 1
  fi
  jar="$(mktemp)"
  if ! curl -fsS -c "$jar" -X POST "${OMNIROUTE_API}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg p "$password" '{password:$p}')" >/dev/null; then
    rm -f "$jar"
    echo "OmniRoute login failed." >&2
    return 1
  fi
  token="$(awk '$6 == "auth_token" { print $7; exit }' "$jar" 2>/dev/null || true)"
  rm -f "$jar"
  if [ -z "$token" ]; then
    echo "OmniRoute login did not return an auth_token cookie." >&2
    return 1
  fi
  printf '%s' "$token"
}

omniroute_curl() {
  local token="$1"
  shift
  # Explicit Cookie header works over http://127.0.0.1 even when the Set-Cookie
  # was marked Secure (AUTH_COOKIE_SECURE=true).
  curl -sS \
    -H "Cookie: auth_token=${token}" \
    -H "Content-Type: application/json" \
    "$@"
}

configure_digitalocean_provider() {
  local key="$1" model="$2" token existing_id http_body http_code
  token="$(omniroute_login_token)" || return 1

  http_body="$(mktemp)"
  http_code="$(omniroute_curl "$token" -o "$http_body" -w '%{http_code}' \
    -X POST "${OMNIROUTE_API}/api/providers" \
    -d "$(jq -n \
      --arg key "$key" \
      --arg model "$model" \
      '{
        provider: "digitalocean",
        apiKey: $key,
        name: "DigitalOcean",
        defaultModel: $model,
        priority: 1
      }')")"

  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    existing_id="$(omniroute_curl "$token" "${OMNIROUTE_API}/api/providers" 2>/dev/null \
      | jq -r '[.[]? | select(.provider=="digitalocean") | .id][0] // empty' 2>/dev/null || true)"
    if [ -z "$existing_id" ]; then
      existing_id="$(jq -r '.id // .connection.id // empty' "$http_body" 2>/dev/null || true)"
    fi
    rm -f "$http_body"
    if [ -n "$existing_id" ]; then
      omniroute_curl "$token" -X POST "${OMNIROUTE_API}/api/providers/${existing_id}/test" \
        -d '{}' >/dev/null 2>&1 || true
    fi
    return 0
  fi

  # Connection may already exist — update apiKey / defaultModel
  existing_id="$(omniroute_curl "$token" "${OMNIROUTE_API}/api/providers" 2>/dev/null \
    | jq -r '[.[]? | select(.provider=="digitalocean") | .id][0] // empty' 2>/dev/null || true)"

  if [ -n "$existing_id" ]; then
    http_code="$(omniroute_curl "$token" -o "$http_body" -w '%{http_code}' \
      -X PATCH "${OMNIROUTE_API}/api/providers/${existing_id}" \
      -d "$(jq -n \
        --arg key "$key" \
        --arg model "$model" \
        '{apiKey:$key, defaultModel:$model, priority:1}')")"
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
      rm -f "$http_body"
      return 0
    fi
  fi

  echo "Failed to configure DigitalOcean provider (HTTP ${http_code})." >&2
  cat "$http_body" >&2 || true
  rm -f "$http_body"
  return 1
}

MODEL_ACCESS_KEY=$(read_config_value MODEL_ACCESS_KEY || true)
INFERENCE_MODEL=$(read_config_value INFERENCE_MODEL || true)
DO_INFERENCE_ROUTER=$(read_config_value DO_INFERENCE_ROUTER || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
  exit 1
fi

write_env_file_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"

PRIMARY_MODEL=""
if env_value_usable "$DO_INFERENCE_ROUTER"; then
  ROUTER_NAME=$(normalize_router_name "$DO_INFERENCE_ROUTER")
  if [ -n "$ROUTER_NAME" ]; then
    PRIMARY_MODEL="router:${ROUTER_NAME}"
    if ! env_value_usable "$INFERENCE_MODEL"; then
      INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
    write_env_file_kv INFERENCE_MODEL "$INFERENCE_MODEL"
    write_env_file_kv DO_INFERENCE_ROUTER "$ROUTER_NAME"
  fi
fi

if [ -z "${PRIMARY_MODEL:-}" ]; then
  if ! env_value_usable "$INFERENCE_MODEL"; then
    CHAT_IDS=""
    if [ -f "$INFERENCE_MODELS_LIB" ]; then
      # shellcheck source=/var/lib/digitalocean/inference-models.sh
      . "$INFERENCE_MODELS_LIB"
      # shellcheck source=/opt/omniroute/inference-helpers.sh
      . "$OMNIROUTE_INFERENCE_HELPERS"
      CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY" | omniroute_filter_chat_models || true)"
    fi
    if [ -n "$CHAT_IDS" ]; then
      INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | omniroute_pick_default_model || true)"
    fi
    if ! env_value_usable "$INFERENCE_MODEL"; then
      INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
  fi
  PRIMARY_MODEL="$INFERENCE_MODEL"
  write_env_file_kv INFERENCE_MODEL "$PRIMARY_MODEL"
  write_env_file_kv DO_INFERENCE_ROUTER ""
fi

wait_for_omniroute

echo "Configuring OmniRoute DigitalOcean provider (model: ${PRIMARY_MODEL})..."
configure_digitalocean_provider "$MODEL_ACCESS_KEY" "$PRIMARY_MODEL"

printf '%s\n' "digitalocean" > "$SETUP_MARKER"
chmod 600 "$SETUP_MARKER"
remove_setup_wizard_bashrc_hook
redact_inference_secrets_from_system_environment

echo "Testing connection to DigitalOcean Serverless Inference..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${MODEL_ACCESS_KEY}" \
  -H "Content-Type: application/json" \
  https://inference.do-ai.run/v1/models 2>/dev/null || true)

if [ "$HTTP_STATUS" = "200" ]; then
  echo "DigitalOcean provider configured: model ${PRIMARY_MODEL}"
else
  echo "DigitalOcean provider configured: model ${PRIMARY_MODEL}"
  echo "Warning: Received HTTP ${HTTP_STATUS:-000} from the Serverless Inference API." >&2
fi

exit 0
