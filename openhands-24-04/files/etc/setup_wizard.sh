#!/bin/bash
# OpenHands first-login setup wizard — API key reminder + optional Gradient config

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
  echo "LLM provider already configured. Skipping Gradient wizard."
  echo "Re-run with --force to configure again: /etc/setup_wizard.sh --force"
  remove_first_login_hook
  exit 0
fi

if [ "${1:-}" != "--force" ] && [ -x /opt/apply-gradient-from-env.sh ] && /opt/apply-gradient-from-env.sh; then
  echo ""
  echo "DigitalOcean Gradient configured from droplet environment."
  remove_first_login_hook
  exit 0
fi

cat <<'EOF'

------------------------------------------------------------------------
  Optional: DigitalOcean Gradient AI
------------------------------------------------------------------------

Configure Gradient so OpenHands can call models via a single model access key.
Create a key at: https://cloud.digitalocean.com/gen-ai
  (API Keys > Model Access Keys)

Examples: minimax-m2.5 (default), kimi-k2.5, glm-5, llama3.3-70b-instruct

You can also skip and set any provider later in Settings > LLM.

EOF

read -r -p "Enter your Gradient model access key (or press Enter to skip): " MODEL_KEY

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Skipped Gradient setup. Configure LLM in the web UI (Settings > LLM),"
  echo "or re-run: /etc/setup_wizard.sh"
  echo ""
  remove_first_login_hook
  exit 0
fi

read -r -p "Gradient model id [minimax-m2.5]: " MODEL_ID
MODEL_ID="${MODEL_ID:-minimax-m2.5}"

# Persist into env file, then apply (plain KEY=value for systemd EnvironmentFile)
tmp="${ENV_FILE}.tmp"
touch "$ENV_FILE"
grep -v -E '^(GRADIENT_KEY|GRADIENT_MODEL)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
printf 'GRADIENT_KEY=%s\n' "$MODEL_KEY" >>"$tmp"
printf 'GRADIENT_MODEL=%s\n' "$MODEL_ID" >>"$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

export GRADIENT_KEY="$MODEL_KEY"
export GRADIENT_MODEL="$MODEL_ID"

echo ""
echo "Testing connection to DigitalOcean Gradient..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${MODEL_KEY}" \
  -H "Content-Type: application/json" \
  https://inference.do-ai.run/v1/models 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "Connection successful! Your key is valid."
else
  echo "Warning: Received HTTP ${HTTP_STATUS} from the Gradient API."
  echo "Saving anyway — re-run /etc/setup_wizard.sh --force if needed."
fi

/opt/apply-gradient-from-env.sh

remove_first_login_hook

cat <<EOF

========================================================================
  Setup complete!

  Open:     https://${myip}
  API Key:  ${API_KEY}
  Model:    openai/${MODEL_ID} via DigitalOcean Gradient

  Projects workspace: /home/openhands/projects
========================================================================

EOF
