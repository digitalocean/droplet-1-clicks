#!/bin/bash

# OpenClaw Token Setup Script
# Run this script to configure OpenClaw with a AI API key

if [ -f /home/openclaw/.openclaw/openclaw.json ]; then
    configured_key=$(jq -r '.models.providers.gradient.apiKey // empty' /home/openclaw/.openclaw/openclaw.json 2>/dev/null || true)
    if [ -n "$configured_key" ] && [ "$configured_key" != "PLACEHOLDER" ] && [ "$configured_key" != "null" ]; then
        echo "DigitalOcean Gradient is already configured. Skipping provider setup."
        sed -i \
            -e '/chmod +x \/etc\/setup_wizard\.sh/d' \
            -e '/\/etc\/setup_wizard\.sh/d' \
            /root/.bashrc 2>/dev/null || true
        echo "Control UI pairing: sudo /opt/openclaw-control-ui-pairing.sh"
        exit 0
    fi
fi

# OpenClaw first-login setup (DigitalOcean 1-Click)
# Configures models and gateway; see authoritative docs at the URLs printed below.

DOCS_MAIN="https://docs.clawd.bot/"
DOCS_OPENAI="https://github.com/openclaw/openclaw/blob/main/docs/providers/openai.md"
DOCS_REPO="https://github.com/openclaw/openclaw"

# Public IPv4 from DO metadata (matches browser URL). Private IP is often first in
# hostname -I — using only that caused gateway.controlUi.allowedOrigins mismatches
# ("origin not allowed") when users opened https://<public-ip>/.
droplet_public_ip() {
  curl -fsS --retry 5 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true
}

DROPL_PRIVATE_IP=$(hostname -I | awk '{print $1}')
DROPL_PUBLIC_IP=$(droplet_public_ip)
if [ -n "$DROPL_PUBLIC_IP" ]; then
  DROPL_IP="$DROPL_PUBLIC_IP"
  DASHBOARD_HOST="$DROPL_PUBLIC_IP"
else
  DROPL_IP="$DROPL_PRIVATE_IP"
  DASHBOARD_HOST="$DROPL_PRIVATE_IP"
fi
remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

read_openclaw_gateway_token() {
  local line val
  if [ -f /opt/openclaw.env ]; then
    line=$(grep -E '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env 2>/dev/null | tail -n 1) || true
    if [ -n "$line" ]; then
      eval "val=${line#OPENCLAW_GATEWAY_TOKEN=}"
      case "$val" in
        ''|*'${'*|PLACEHOLDER*) ;;
        *) printf '%s' "$val"; return 0 ;;
      esac
    fi
  fi
  if [ -f /home/openclaw/.openclaw/openclaw.json ]; then
    jq -r '.gateway.auth.token // .gateway.remote.token // empty' \
      /home/openclaw/.openclaw/openclaw.json 2>/dev/null | \
      grep -vE '^(null|PLACEHOLDER|\$\{)' || true
  fi
}

PS3="Select a provider (1-6): "
options=(
  "GradientAI"
  "OpenAI (API key — usage billing)"
  "OpenAI Codex (ChatGPT / subscription OAuth)"
  "Anthropic"
  "OpenRouter"
  "OpenClaw Model Setup"
)

echo ""
echo "========================================================================"
echo "  OpenClaw — authoritative documentation"
echo "========================================================================"
echo "  Project docs:     ${DOCS_MAIN}"
echo "  OpenAI & Codex:   ${DOCS_OPENAI}"
echo "  Source / issues:  ${DOCS_REPO}"
echo "========================================================================"
echo ""
echo "OpenAI has two different setups: an API key (platform billing) vs"
echo "ChatGPT/Codex subscription (OAuth). They are not interchangeable — see the"
echo "OpenAI provider doc above before changing config."
echo ""
echo "--- AI Provider Selector ---"

selected_provider="n/a"
target_config="n/a"

select opt in "${options[@]}"
do
  case $opt in
    "GradientAI")
        selected_provider="GradientAI"
        target_config="/etc/config/gradientai.json"
        echo "You selected DigitalOcean GradientAI."
        echo "Default model: MiniMax M2.5. Also available: Kimi K2.5, GLM 5, Llama 3.3 70B, DeepSeek, GPT OSS, Claude 4.5 Sonnet (see /etc/config/gradientai.json)."
        break
        ;;
    "OpenAI (API key — usage billing)")
        selected_provider="OpenAI"
        target_config="/etc/config/openai.json"
        env_key_name="OPENAI_API_KEY"
        echo "You selected OpenAI via API key (OPENAI_API_KEY)."
        echo "For ChatGPT / Codex subscription (OAuth), cancel (Ctrl+C) and choose"
        echo "'OpenAI Codex' instead, or see: ${DOCS_OPENAI}"
        break
        ;;
    "OpenAI Codex (ChatGPT / subscription OAuth)")
        selected_provider="OpenAI Codex"
        target_config=""
        echo "You selected OpenAI Codex (subscription OAuth via OpenClaw onboard)."
        echo "Follow the prompts. Official details: ${DOCS_OPENAI}"
        break
        ;;
    "Anthropic")
        selected_provider="Anthropic"
        target_config="/etc/config/anthropic.json"
        env_key_name="ANTHROPIC_API_KEY"
        echo "You selected Anthropic."
        break
        ;;
    "OpenRouter")
        selected_provider="OpenRouter"
        target_config="/etc/config/openrouter.json"
        env_key_name="OPENROUTER_API_KEY"
        echo "You selected OpenRouter."
        break
        ;;
    "OpenClaw Model Setup")
        selected_provider="OpenClaw Model Setup"
        target_config="/etc/config/openclaw.json"
        echo "You selected OpenClaw Built-in Model Setup."
        echo "When prompted 'Where will the Gateway run?' please select 'Local'"
        break
        ;;
    *)
        echo "Invalid option. Please try again."
        ;;
  esac
done

echo ""
echo "${selected_provider} Configuration Setup"
echo "=============================="
echo ""

mkdir -p /home/openclaw/.openclaw

if [[ "$selected_provider" == "OpenClaw Model Setup" ]]; then
  /opt/openclaw-cli.sh configure --section model
  jq -s '.[0] * .[1]' /home/openclaw/.openclaw/openclaw.json ${target_config} > /home/openclaw/.openclaw/openclaw.json.bak
  cp /home/openclaw/.openclaw/openclaw.json.bak /home/openclaw/.openclaw/openclaw.json
elif [[ "$selected_provider" == "OpenAI Codex" ]]; then
  echo "Starting OpenClaw onboarding for Codex (interactive; browser / device flow may be required)..."
  echo "Reference: ${DOCS_OPENAI}"
  if /opt/openclaw-cli.sh onboard --auth-choice openai-codex; then
    :
  else
    echo ""
    echo "Note: 'onboard --auth-choice openai-codex' failed or is unavailable in this CLI version."
    echo "Running generic interactive onboard; choose OpenAI / Codex when prompted."
    echo "Docs: ${DOCS_MAIN}"
    /opt/openclaw-cli.sh onboard || true
  fi
  if [ ! -f /home/openclaw/.openclaw/openclaw.json ]; then
    echo "Seeding minimal gateway config (onboard did not create openclaw.json)."
    cp /etc/config/openclaw.json /home/openclaw/.openclaw/openclaw.json
    chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
  fi
else
  while [ -z "${model_access_key:-}" ]
    do
      read -p "Enter ${selected_provider} model access key: " model_access_key
    done
  if [[ "$selected_provider" == "GradientAI" ]]; then
      jq --arg key "$model_access_key" '.models.providers.gradient.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
  elif [[ "$selected_provider" == "OpenRouter" ]]; then
      jq --arg key "$model_access_key" '.models.providers.openrouter.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
  else
      cp ${target_config} /home/openclaw/.openclaw/openclaw.json
      echo -e "\n${env_key_name}=${model_access_key}" >> /opt/openclaw.env
  fi
fi

chmod +x /opt/sync-openclaw-gateway.sh
/opt/sync-openclaw-gateway.sh

GATEWAY_TOKEN=$(read_openclaw_gateway_token)
if [ -z "$GATEWAY_TOKEN" ]; then
  echo "ERROR: Could not read OPENCLAW_GATEWAY_TOKEN from /opt/openclaw.env or openclaw.json." >&2
  exit 1
fi

echo "gateway.controlUi.allowedOrigins -> $(jq -c '.gateway.controlUi.allowedOrigins' /home/openclaw/.openclaw/openclaw.json)"
echo "gateway.auth.token / gateway.remote.token -> configured"
echo "(Open the Control UI at https://${DASHBOARD_HOST}/ so the browser Origin matches.)"

chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 0600 /home/openclaw/.openclaw/openclaw.json

echo ""
if [[ "$selected_provider" == "OpenAI Codex" ]]; then
  echo "OpenClaw Codex onboarding step finished. Run /opt/openclaw-cli.sh doctor if your CLI version supports it."
else
  echo "${selected_provider} key configured successfully."
fi
echo "Authoritative docs: ${DOCS_MAIN} | OpenAI/Codex: ${DOCS_OPENAI}"
echo "Restarting OpenClaw service..."
systemctl restart openclaw

sleep 2

if systemctl is-active --quiet openclaw; then
    echo "✅ OpenClaw restarted successfully!"
else
    echo "⚠️ Service may need attention. Check with: systemctl status openclaw"
fi

cp -r /usr/lib/node_modules/openclaw/skills /home/openclaw/.openclaw/workspace/ 2>/dev/null || true

remove_first_login_hook
chmod +x /opt/openclaw-control-ui-pairing.sh
exec /opt/openclaw-control-ui-pairing.sh