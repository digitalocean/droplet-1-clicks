#!/bin/bash
# OmniRoute first-login setup wizard — password reminder + optional Serverless Inference

set -euo pipefail

SETUP_MARKER=/opt/omniroute/.provider-configured
ENV_FILE=/opt/omniroute/.env
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
OMNIROUTE_INFERENCE_HELPERS=/opt/omniroute/inference-helpers.sh
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

read_password() {
  local line val
  line=$(grep -E '^INITIAL_PASSWORD=' "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
  val="${line#INITIAL_PASSWORD=}"
  val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
  printf '%s' "$val"
}

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
PASSWORD="$(read_password || true)"

cat <<EOF

========================================================================
  OmniRoute first-login setup
========================================================================

Dashboard: https://${myip}
Password:  ${PASSWORD:-"(see /opt/omniroute/.env INITIAL_PASSWORD)"}

Sign in, then open Providers / Endpoints in the dashboard.
API base URL for clients: https://${myip}/v1

Docs: https://github.com/diegosouzapw/OmniRoute
EOF

if [ -f "$SETUP_MARKER" ] && [ "${1:-}" != "--force" ]; then
  echo ""
  echo "DigitalOcean provider already configured. Skipping Serverless Inference wizard."
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

Configure Serverless Inference so OmniRoute uses DigitalOcean as its preferred
provider. Create a model access key at:
  https://cloud.digitalocean.com/gen-ai
  (API Keys > Model Access Keys)

You can also skip and add any provider later in the OmniRoute dashboard.

EOF

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your DigitalOcean model access key (or press Enter to skip): " MODEL_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Skipped Serverless Inference setup. Configure providers in the dashboard,"
  echo "or re-run: /etc/setup_wizard.sh"
  echo ""
  remove_first_login_hook
  exit 0
fi

# shellcheck source=/var/lib/digitalocean/inference-models.sh
. "$INFERENCE_MODELS_LIB"
# shellcheck source=/opt/omniroute/inference-helpers.sh
. "$OMNIROUTE_INFERENCE_HELPERS"

echo ""
echo "Fetching available models from DigitalOcean Serverless Inference..."

json=""
chat_ids=""
INFERENCE_MODEL=""
DO_INFERENCE_ROUTER=""
while true; do
  if json="$(fetch_inference_models_json "$MODEL_KEY")"; then
    chat_ids="$(omniroute_list_chat_models_from_json "$json")"
    if [ -z "$chat_ids" ]; then
      chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | omniroute_filter_chat_models)"
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
  echo "Setup skipped. Re-run later: /etc/setup_wizard.sh"
  echo ""
  remove_first_login_hook
  exit 0
done

ROUTER_NAME=""
CHOSEN_LABEL=""
if [ -n "$chat_ids" ]; then
  default_model="$(printf '%s\n' "$chat_ids" | omniroute_pick_default_model)"
  echo ""
  echo "Choose a default model (you can change it later in the dashboard):"
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
  INFERENCE_MODEL="$DEFAULT_MODEL"
  CHOSEN_LABEL="$DEFAULT_MODEL"
fi

# Persist into env file, then apply
tmp="${ENV_FILE}.tmp"
touch "$ENV_FILE"
grep -v -E '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
printf 'MODEL_ACCESS_KEY=%s\n' "$MODEL_KEY" >>"$tmp"
if [ -n "$ROUTER_NAME" ]; then
  printf 'INFERENCE_MODEL=%s\n' "$DEFAULT_MODEL" >>"$tmp"
  printf 'DO_INFERENCE_ROUTER=%s\n' "$ROUTER_NAME" >>"$tmp"
  CHOSEN_LABEL="${CHOSEN_LABEL:-Intelligent Inference Router (router:${ROUTER_NAME})}"
else
  printf 'INFERENCE_MODEL=%s\n' "$INFERENCE_MODEL" >>"$tmp"
  printf 'DO_INFERENCE_ROUTER=\n' >>"$tmp"
fi
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

export MODEL_ACCESS_KEY="$MODEL_KEY"
if [ -n "$ROUTER_NAME" ]; then
  export INFERENCE_MODEL="$DEFAULT_MODEL"
  export DO_INFERENCE_ROUTER="$ROUTER_NAME"
else
  export INFERENCE_MODEL
  export DO_INFERENCE_ROUTER=""
fi

/opt/apply-inference-from-env.sh

echo ""
echo "========================================================================"
echo "  Setup complete! OmniRoute is ready."
echo ""
echo "  Dashboard: https://${myip}"
echo "  Password:  ${PASSWORD:-"(see /opt/omniroute/.env)"}"
echo "  Default:   ${CHOSEN_LABEL}"
echo ""
echo "  Create an Endpoint API key in the dashboard to call https://${myip}/v1"
echo "========================================================================"
echo ""

remove_first_login_hook
exit 0
