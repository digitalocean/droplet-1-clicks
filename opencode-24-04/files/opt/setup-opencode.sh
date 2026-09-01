#!/bin/bash

# OpenCode First-Login Setup Wizard
# Prompts for a DigitalOcean model access key, lists live models, and
# configures OpenCode.

SETUP_MARKER="/root/.opencode_setup_complete"
CONFIG_FILE="/root/.config/opencode/opencode.json"
AUTH_FILE="/root/.local/share/opencode/auth.json"
ENV_FILE="/opt/opencode.env"
INFERENCE_MODELS_LIB="/var/lib/digitalocean/inference-models.sh"

remove_first_login_hook() {
  sed -i '/\/opt\/setup-opencode\.sh/d' /root/.bashrc 2>/dev/null || true
}

save_env_kv() {
  local key="$1" val="$2"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || : > "${ENV_FILE}.tmp"
  printf '%s=%q\n' "$key" "$val" >> "${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

try_apply_inference_from_env() {
  set -a
  # shellcheck source=/dev/null
  source /etc/environment 2>/dev/null || true
  set +a

  if [ -x /opt/apply-inference-from-env.sh ] && /opt/apply-inference-from-env.sh; then
    echo "DigitalOcean Serverless Inference configured from droplet environment."
    remove_first_login_hook
    return 0
  fi

  return 1
}

# Startup scripts may land in /etc/environment after 001_onboot; retry before prompting.
if [ "$1" != "--force" ] && try_apply_inference_from_env; then
  exit 0
fi

inference_already_configured() {
  local configured_key

  if [ -f "$SETUP_MARKER" ]; then
    echo "OpenCode setup is already complete"
    return 0
  fi

  if [ -f "$AUTH_FILE" ]; then
    configured_key=$(jq -r '.digitalocean.key // empty' "$AUTH_FILE" 2>/dev/null || true)
    if [ -n "$configured_key" ] && [ "$configured_key" != "null" ]; then
      echo "DigitalOcean Serverless Inference is already configured"
      return 0
    fi
  fi

  return 1
}

configured_reason=$(inference_already_configured || true)
if [ -n "$configured_reason" ] && [ "$1" != "--force" ]; then
  echo "${configured_reason}. Skipping setup wizard."
  remove_first_login_hook
  exit 0
fi

if [ ! -f "$INFERENCE_MODELS_LIB" ]; then
  echo "ERROR: missing $INFERENCE_MODELS_LIB" >&2
  exit 1
fi
# shellcheck source=/var/lib/digitalocean/inference-models.sh
. "$INFERENCE_MODELS_LIB"

echo ""
echo "========================================================================"
echo "  OpenCode Setup - DigitalOcean Serverless Inference"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured with DigitalOcean Serverless Inference. A single"
echo "model access key unlocks the current chat model catalog"
echo "(fetched live from the inference API) plus the Intelligent Inference Router."
echo ""
echo "To create a DigitalOcean model access key:"
echo "  1. Go to https://cloud.digitalocean.com/gen-ai"
echo "  2. Navigate to API Keys > Model Access Keys"
echo "  3. Click 'Create Model Access Key'"
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your DigitalOcean model access key (or press Enter to skip): " MODEL_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Setup skipped. You can configure your key later by running:"
  echo "  /opt/setup-opencode.sh"
  echo ""
  exit 0
fi

echo ""
echo "Fetching available models from DigitalOcean Serverless Inference..."

json=""
chat_ids=""
INFERENCE_MODEL=""
DO_INFERENCE_ROUTER=""
while true; do
  if json="$(fetch_inference_models_json "$MODEL_KEY")"; then
    chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
    if [ -z "$chat_ids" ]; then
      chat_ids="$(printf '%s' "$json" | parse_inference_model_ids)"
    fi
    if [ -n "$chat_ids" ]; then
      break
    fi
    echo "The Serverless Inference API returned no models for this key."
  else
    status="${INFERENCE_MODELS_HTTP_STATUS:-000}"
    if [ "$status" = "401" ] || [ "$status" = "403" ]; then
      echo "That key was rejected (HTTP ${status})."
    else
      echo "Could not list models from https://inference.do-ai.run/v1/models (HTTP ${status})."
    fi
  fi

  echo ""
  echo "You can re-enter the key, type a model id to use this key anyway, or skip."
  old_histfile="${HISTFILE-}"
  unset HISTFILE
  read -rsp "Re-enter your DigitalOcean model access key (or press Enter to keep the current key): " NEW_KEY
  echo ""
  [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"
  if [ -n "${NEW_KEY}" ]; then
    MODEL_KEY="$NEW_KEY"
    continue
  fi

  read -rp "Enter an inference model id (or press Enter to skip setup): " INFERENCE_MODEL
  if [ -n "${INFERENCE_MODEL}" ]; then
    chat_ids=""
    break
  fi

  echo ""
  echo "Setup skipped. Re-run later: /opt/setup-opencode.sh"
  echo ""
  exit 0
done

CHOSEN_LABEL=""
if [ -n "$chat_ids" ]; then
  default_model="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
  echo ""
  echo "Choose a default model (you can switch later with /models):"
  echo ""
  i=1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf "  %2d) %s\n" "$i" "$line"
    i=$((i + 1))
  done <<<"$chat_ids"
  echo "   R) DigitalOcean Intelligent Inference Router (auto-picks the best model)"
  echo ""
  count=$((i - 1))
  read -rp "Selection [1-${count} / R, or Enter for ${default_model}]: " SEL

  if [ "$SEL" = "R" ] || [ "$SEL" = "r" ]; then
    echo ""
    echo "Create a router under Inference > Routers, then enter its name."
    read -rp "Router name: " ROUTER_NAME
    if [ -n "$ROUTER_NAME" ]; then
      ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
      ROUTER_NAME="${ROUTER_NAME#router:}"
      DO_INFERENCE_ROUTER="$ROUTER_NAME"
      CHOSEN_LABEL="Intelligent Inference Router (digitalocean/router:${ROUTER_NAME})"
    else
      echo "No router name entered; keeping ${default_model}."
      INFERENCE_MODEL="$default_model"
    fi
  elif ! INFERENCE_MODEL="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "$SEL")"; then
    echo "Invalid selection; using ${default_model}."
    INFERENCE_MODEL="$default_model"
  fi
fi

save_env_kv MODEL_ACCESS_KEY "$MODEL_KEY"
export MODEL_ACCESS_KEY="$MODEL_KEY"
if [ -n "$DO_INFERENCE_ROUTER" ]; then
  save_env_kv DO_INFERENCE_ROUTER "$DO_INFERENCE_ROUTER"
  export DO_INFERENCE_ROUTER
  save_env_kv INFERENCE_MODEL ""
  export INFERENCE_MODEL=""
else
  save_env_kv INFERENCE_MODEL "$INFERENCE_MODEL"
  save_env_kv DO_INFERENCE_ROUTER ""
  export INFERENCE_MODEL
  export DO_INFERENCE_ROUTER=""
fi

/opt/apply-inference-from-env.sh

if [ -z "$CHOSEN_LABEL" ]; then
  CHOSEN_LABEL="digitalocean/${INFERENCE_MODEL}"
fi

touch "$SETUP_MARKER"
remove_first_login_hook

echo ""
echo "========================================================================"
echo "  Setup complete! OpenCode is ready to use."
echo ""
echo "  Default model: ${CHOSEN_LABEL}"
echo ""
echo "  To start:  cd /path/to/your/project && opencode"
echo "  Config:    /root/.config/opencode/opencode.json"
echo "  Auth:      /root/.local/share/opencode/auth.json"
echo "  Switch models:    use /models inside OpenCode"
echo "  Other providers:  use /connect to add Anthropic, OpenAI, Google, etc."
echo "========================================================================"
echo ""
