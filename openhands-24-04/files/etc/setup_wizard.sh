#!/bin/bash
# OpenHands first-login setup wizard — API key reminder + optional Serverless Inference config

set -euo pipefail

SETUP_DONE_MARKER=/home/openhands/.openhands/provider-configured
ENV_FILE=/opt/openhands.env

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

read_api_key() {
  local line val
  line=$(grep -E '^LOCAL_BACKEND_API_KEY=' "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
  val="${line#LOCAL_BACKEND_API_KEY=}"
  val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
  printf '%s' "$val"
}

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
API_KEY="$(read_api_key || true)"

cat <<EOF

========================================================================
  OpenHands (Agent Canvas) first-login setup
========================================================================

Web UI:  https://${myip}
API Key: ${API_KEY:-"(see /opt/openhands.env or /home/openhands/.openhands/api-key.txt)"}

Paste the API key when the browser prompts for it.

Docs: https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm
EOF

if [ -f "$SETUP_DONE_MARKER" ] && [ "${1:-}" != "--force" ]; then
  echo ""
  echo "LLM provider already configured. Skipping Serverless Inference wizard."
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

Configure Serverless Inference so OpenHands can call models via a single model access key.
Create a key at: https://cloud.digitalocean.com/gen-ai
  (API Keys > Model Access Keys)

Examples: minimax-m2.5 (default), kimi-k2.5, glm-5, llama3.3-70b-instruct

You can also skip and set any provider later in Settings > LLM.

EOF

read -r -p "Enter your DigitalOcean model access key (or press Enter to skip): " MODEL_KEY

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Skipped Serverless Inference setup. Configure LLM in the web UI (Settings > LLM),"
  echo "or re-run: /etc/setup_wizard.sh"
  echo ""
  remove_first_login_hook
  exit 0
fi

echo "Choose a default model (you can change it later in Settings > LLM):"
echo "  Press Enter for MiniMax M2.5, enter a model id, or R for the"
echo "  Intelligent Inference Router."
read -r -p "Model id [minimax-m2.5 / R]: " MODEL_SEL

ROUTER_NAME=""
MODEL_ID="minimax-m2.5"
if [ "$MODEL_SEL" = "R" ] || [ "$MODEL_SEL" = "r" ]; then
  echo ""
  echo "Create a router under Inference > Routers, then enter its name."
  read -r -p "Router name: " ROUTER_NAME
  ROUTER_NAME="${ROUTER_NAME#openai/}"
  ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
  ROUTER_NAME="${ROUTER_NAME#router:}"
  if [ -z "$ROUTER_NAME" ]; then
    echo "No router name entered; keeping MiniMax M2.5."
  else
    MODEL_ID="router:${ROUTER_NAME}"
  fi
elif [ -n "$MODEL_SEL" ]; then
  MODEL_ID="$MODEL_SEL"
fi

# Persist into env file, then apply (plain KEY=value for systemd EnvironmentFile)
tmp="${ENV_FILE}.tmp"
touch "$ENV_FILE"
grep -v -E '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
printf 'MODEL_ACCESS_KEY=%s\n' "$MODEL_KEY" >>"$tmp"
printf 'INFERENCE_MODEL=%s\n' "$MODEL_ID" >>"$tmp"
printf 'DO_INFERENCE_ROUTER=%s\n' "$ROUTER_NAME" >>"$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

export MODEL_ACCESS_KEY="$MODEL_KEY"
export INFERENCE_MODEL="$MODEL_ID"
export DO_INFERENCE_ROUTER="$ROUTER_NAME"

echo ""
echo "Testing connection to DigitalOcean Serverless Inference..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${MODEL_KEY}" \
  -H "Content-Type: application/json" \
  https://inference.do-ai.run/v1/models 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "Connection successful! Your key is valid."
else
  echo "Warning: Received HTTP ${HTTP_STATUS} from the Serverless Inference API."
  echo "Saving anyway — re-run /etc/setup_wizard.sh --force if needed."
fi

/opt/apply-inference-from-env.sh

remove_first_login_hook

cat <<EOF

========================================================================
  Setup complete!

  Open:     https://${myip}
  API Key:  ${API_KEY}
  Model:    openai/${MODEL_ID#openai/} via DigitalOcean Serverless Inference

  Projects workspace: /home/openhands/projects
========================================================================

EOF
