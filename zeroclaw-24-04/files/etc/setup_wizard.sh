#!/bin/bash

# ZeroClaw Provider Setup Script
# Run this script to configure ZeroClaw with an AI API key

ENV_FILE=/opt/zeroclaw.env
SETUP_MARKER=/root/.zeroclaw_setup_complete
CONFIG_DIR="/home/zeroclaw/.zeroclaw"
CONFIG_FILE="${CONFIG_DIR}/config.toml"

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

gradient_already_configured() {
  local api_key
  [ -f "$CONFIG_FILE" ] || return 1
  api_key=$(grep -E '^api_key\s*=' "$CONFIG_FILE" 2>/dev/null | tail -n 1 | sed 's/^api_key\s*=\s*"\?\([^"]*\)"\?.*/\1/') || return 1
  case "$api_key" in
    ''|PLACEHOLDER|*'${'*) return 1 ;;
  esac
  return 0
}

write_gradient_env_key() {
  local key="$1" model="$2"
  umask 077
  touch "$ENV_FILE"
  grep -Ev '^(GRADIENT_KEY|GRADIENT_MODEL)=' "$ENV_FILE" >"${ENV_FILE}.tmp" 2>/dev/null || : >"${ENV_FILE}.tmp"
  printf 'GRADIENT_KEY=%q\n' "$key" >>"${ENV_FILE}.tmp"
  printf 'GRADIENT_MODEL=%q\n' "$model" >>"${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

DROPL_IP=$(hostname -I | awk '{print$1}')

if [ "$1" != "--force" ]; then
  if [ -f "$SETUP_MARKER" ] || gradient_already_configured; then
    echo "ZeroClaw provider is already configured. Skipping setup."
    remove_first_login_hook
    exit 0
  fi
  if [ -x /opt/apply-gradient-from-env.sh ] && /opt/apply-gradient-from-env.sh; then
    remove_first_login_hook
    exit 0
  fi
fi

PS3="Select a provider (1-4): "
options=("DigitalOcean Gradient" "OpenAI" "Anthropic" "OpenRouter")

echo "--- ZeroClaw AI Provider Setup ---"

selected_provider="n/a"
onboard_provider=""
onboard_model=""

select opt in "${options[@]}"
do
  case $opt in
    "DigitalOcean Gradient")
        selected_provider="DigitalOcean Gradient"
        onboard_provider="custom:https://inference.do-ai.run/v1"
        echo "You selected DigitalOcean Gradient."
        echo ""
        echo "Choose a Gradient inference model (default: Kimi K2.5):"
        PS3="Select model (1-4): "
        gradient_options=("Kimi K2.5" "MiniMax M2.5" "GLM 5" "Claude Sonnet 4.5")
        select gopt in "${gradient_options[@]}"
        do
          case $gopt in
            "Kimi K2.5")
              onboard_model="kimi-k2.5"
              echo "Using Kimi K2.5 (kimi-k2.5)."
              break 2
              ;;
            "MiniMax M2.5")
              onboard_model="minimax-m2.5"
              echo "Using MiniMax M2.5 (minimax-m2.5)."
              break 2
              ;;
            "GLM 5")
              onboard_model="glm-5"
              echo "Using GLM 5 (glm-5)."
              break 2
              ;;
            "Claude Sonnet 4.5")
              onboard_model="anthropic-claude-4.5-sonnet"
              echo "Using Claude Sonnet 4.5 (anthropic-claude-4.5-sonnet)."
              break 2
              ;;
            *)
              echo "Invalid option. Please try again."
              ;;
          esac
        done
        ;;
    "OpenAI")
        selected_provider="OpenAI"
        onboard_provider="openai"
        onboard_model="gpt-4o-mini"
        echo "You selected OpenAI."
        break
        ;;
    "Anthropic")
        selected_provider="Anthropic"
        onboard_provider="anthropic"
        onboard_model="claude-sonnet-4-6"
        echo "You selected Anthropic."
        break
        ;;
    "OpenRouter")
        selected_provider="OpenRouter"
        onboard_provider="openrouter"
        onboard_model="anthropic/claude-sonnet-4-6"
        echo "You selected OpenRouter."
        break
        ;;
    *)
        echo "Invalid option. Please try again."
        ;;
  esac
done

if [[ "$onboard_provider" == "custom:https://inference.do-ai.run/v1" && -z "$onboard_model" ]]; then
  onboard_model="kimi-k2.5"
fi

echo ""
echo "${selected_provider} Configuration Setup"
echo "=============================="
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
while [ -z "${model_access_key:-}" ]; do
  read -rsp "Enter ${selected_provider} API key: " model_access_key
  echo ""
done
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [[ "$onboard_provider" == "custom:https://inference.do-ai.run/v1" ]]; then
  write_gradient_env_key "$model_access_key" "$onboard_model"
  /opt/apply-gradient-from-env.sh
else
  /opt/zeroclaw-run-onboard.sh "$model_access_key" "$onboard_provider" "$onboard_model"
  umask 077
  touch "$SETUP_MARKER"
  chmod 600 "$SETUP_MARKER"
  systemctl enable zeroclaw
  systemctl restart zeroclaw
fi

remove_first_login_hook

echo ""
echo "${selected_provider} key configured successfully."
echo "Starting ZeroClaw service..."

sleep 3

if systemctl is-active --quiet zeroclaw; then
    echo "ZeroClaw restarted successfully!"
else
    echo "Service may need attention. Check with: systemctl status zeroclaw"
fi

echo ""
echo "ZeroClaw is now running with ${selected_provider}."
echo ""
echo "Access the gateway at: https://${DROPL_IP}"
echo ""
echo "To set up a domain with automatic HTTPS, run:"
echo "  sudo /opt/setup-zeroclaw-domain.sh"
echo ""
echo "Check the pairing code with:"
echo "  journalctl -u zeroclaw --no-pager | grep -i pairing"
echo ""
echo "Or use the CLI:"
echo "  /opt/zeroclaw-cli.sh status"
echo ""
echo "Setup complete!"

cp /etc/skel/.bashrc /root
