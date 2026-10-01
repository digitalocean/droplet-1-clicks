#!/bin/bash
# Paperclip first-login setup wizard — bootstrap reminder + optional Serverless Inference

set -euo pipefail

SETUP_MARKER=/opt/paperclip/.provider-configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
DEFAULT_MODEL=minimax-m2.5

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

env_value_usable() {
  local v="$1"
  [ -n "$v" ] || return 1
  case "$v" in
    *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
  esac
  return 0
}

ENV_FILE=/opt/paperclip.env

read_env_kv() {
  local key="$1" line val
  line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
  printf '%s' "$val"
}

# OmniRoute-style password read for console display
read_password() {
  local line val
  line=$(grep -E '^INITIAL_PASSWORD=' "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
  val="${line#INITIAL_PASSWORD=}"
  val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
  case "$val" in
    ''|PLACEHOLDER*) return 1 ;;
  esac
  printf '%s' "$val"
}

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
email="$(read_env_kv ADMIN_EMAIL || true)"
PASSWORD="$(read_password || true)"

cat <<EOF

========================================================================
  Paperclip first-login setup
========================================================================

Dashboard: https://${myip}
Email:     ${email:-admin@paperclip.local}
Password:  ${PASSWORD:-"(see /opt/paperclip.env INITIAL_PASSWORD)"}

Sign in, then complete onboarding in the dashboard (company, agents, goals).

Docs: https://github.com/paperclipai/paperclip
EOF

if [ -f "$SETUP_MARKER" ] && [ "${1:-}" != "--force" ]; then
  echo ""
  echo "DigitalOcean Serverless Inference already configured. Skipping wizard."
  echo "Re-run with --force to configure again: /etc/setup_wizard.sh --force"
  remove_first_login_hook
  exit 0
fi

if [ "${1:-}" != "--force" ] && [ -x /opt/apply-inference-from-env.sh ] && /opt/apply-inference-from-env.sh; then
  echo ""
  echo "DigitalOcean Serverless Inference configured from droplet environment."
  remove_first_login_hook
  exit 0
fi

cat <<'EOF'

------------------------------------------------------------------------
  Optional: DigitalOcean Serverless Inference
------------------------------------------------------------------------

Configure Serverless Inference so agents can use DigitalOcean as a preferred
provider (OpenAI-compatible). Create a model access key at:
  https://cloud.digitalocean.com/model-studio/manage-keys
  (cloud console: Inference > Manage > Create Model Access Key)

You can also skip and add any provider later in the Paperclip UI.

EOF

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your DigitalOcean model access key (or press Enter to skip): " MODEL_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Skipped Serverless Inference setup for now."
  echo "This prompt will run again on the next SSH login until a key is configured."
  echo "Or run later: /etc/setup_wizard.sh"
  echo ""
  # Keep the .bashrc hook so reopen / next login asks again
  exit 0
fi

HAVE_MODELS_LIB=0
if [ -f "$INFERENCE_MODELS_LIB" ]; then
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"
  HAVE_MODELS_LIB=1
fi

echo ""
echo "Fetching available models from DigitalOcean Serverless Inference..."

json=""
chat_ids=""
INFERENCE_MODEL=""
DO_INFERENCE_ROUTER=""
while true; do
  if [ "$HAVE_MODELS_LIB" = "1" ]; then
    if json="$(fetch_inference_models_json "$MODEL_KEY")"; then
      chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
      if [ -n "$chat_ids" ]; then
        break
      fi
      echo "The Serverless Inference API returned no chat models for this key."
    else
      status="${INFERENCE_MODELS_HTTP_STATUS:-000}"
      if [ "$status" = "401" ] || [ "$status" = "403" ]; then
        echo "That key was rejected (HTTP ${status})."
      else
        echo "Could not list models from https://inference.do-ai.run/v1/models (HTTP ${status})."
      fi
    fi
  else
    break
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
  echo "Setup skipped for now. Next SSH login will ask again."
  echo "Or run later: /etc/setup_wizard.sh"
  echo ""
  # Keep the .bashrc hook so reopen / next login asks again
  exit 0
done

ROUTER_NAME=""
CHOSEN_LABEL=""
if [ -n "$chat_ids" ]; then
  default_model="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
  echo ""
  echo "Choose a default model (you can change it later):"
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
    ROUTER_NAME="${ROUTER_NAME#openai/}"
    ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
    ROUTER_NAME="${ROUTER_NAME#router:}"
    if [ -n "$ROUTER_NAME" ]; then
      CHOSEN_LABEL="Intelligent Inference Router (router:${ROUTER_NAME})"
    else
      echo "No router name entered; keeping ${default_model}."
      INFERENCE_MODEL="$default_model"
      CHOSEN_LABEL="$default_model"
    fi
  elif [ -z "$SEL" ]; then
    INFERENCE_MODEL="$default_model"
    CHOSEN_LABEL="$default_model"
  elif ! INFERENCE_MODEL="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "$SEL")"; then
    echo "Invalid selection; using ${default_model}."
    INFERENCE_MODEL="$default_model"
    CHOSEN_LABEL="$default_model"
  else
    CHOSEN_LABEL="$INFERENCE_MODEL"
  fi
elif [ -n "$INFERENCE_MODEL" ]; then
  CHOSEN_LABEL="$INFERENCE_MODEL"
else
  echo ""
  echo "Choose a default model (you can change it later):"
  echo "  Press Enter for MiniMax M2.5, enter a model id, or R for the"
  echo "  Intelligent Inference Router."
  read -rp "Model id [${DEFAULT_MODEL} / R]: " MODEL_SEL
  if [ "$MODEL_SEL" = "R" ] || [ "$MODEL_SEL" = "r" ]; then
    read -rp "Router name: " ROUTER_NAME
    ROUTER_NAME="${ROUTER_NAME#openai/}"
    ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
    ROUTER_NAME="${ROUTER_NAME#router:}"
    if [ -n "$ROUTER_NAME" ]; then
      CHOSEN_LABEL="Intelligent Inference Router (router:${ROUTER_NAME})"
    else
      INFERENCE_MODEL="$DEFAULT_MODEL"
      CHOSEN_LABEL="$DEFAULT_MODEL"
    fi
  elif [ -n "$MODEL_SEL" ]; then
    INFERENCE_MODEL="$MODEL_SEL"
    CHOSEN_LABEL="$INFERENCE_MODEL"
  else
    INFERENCE_MODEL="$DEFAULT_MODEL"
    CHOSEN_LABEL="$DEFAULT_MODEL"
  fi
fi

# Persist into env via exports; apply-inference-from-env.sh writes safely (no grep -v rewrite)
export MODEL_ACCESS_KEY="$MODEL_KEY"
if [ -n "$ROUTER_NAME" ]; then
  export INFERENCE_MODEL="$DEFAULT_MODEL"
  export DO_INFERENCE_ROUTER="$ROUTER_NAME"
  CHOSEN_LABEL="${CHOSEN_LABEL:-Intelligent Inference Router (router:${ROUTER_NAME})}"
else
  export INFERENCE_MODEL="$INFERENCE_MODEL"
  export DO_INFERENCE_ROUTER=""
fi

# Cache the live model list for MOTD before apply (apply may also refresh it)
if [ -n "$chat_ids" ]; then
  mkdir -p /opt/paperclip
  printf '%s\n' "$chat_ids" > /opt/paperclip/available-models.txt
  chmod 644 /opt/paperclip/available-models.txt
fi

/opt/apply-inference-from-env.sh

# Re-read credentials so the completion banner always matches MOTD / env file
email="$(read_env_kv ADMIN_EMAIL || true)"
PASSWORD="$(read_password || true)"

echo ""
echo "========================================================================"
echo "  Setup complete! Paperclip is ready."
echo ""
echo "  Dashboard: https://${myip}"
echo "  Email:     ${email:-admin@paperclip.local}"
echo "  Password:  ${PASSWORD:-"(see /opt/paperclip.env INITIAL_PASSWORD)"}"
echo "  Default:   ${CHOSEN_LABEL}"
echo "========================================================================"
echo ""

remove_first_login_hook
exit 0
