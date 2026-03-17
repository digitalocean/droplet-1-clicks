#!/bin/bash

# ZeroClaw Provider Setup Script
# Run this script to configure ZeroClaw with an AI API key

DROPL_IP=$(hostname -I | awk '{print$1}')
CONFIG_DIR="/home/zeroclaw/.zeroclaw"
CONFIG_FILE="${CONFIG_DIR}/config.toml"

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
        onboard_model="anthropic-claude-4.5-sonnet"
        echo "You selected DigitalOcean Gradient."
        break
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

echo ""
echo "${selected_provider} Configuration Setup"
echo "=============================="
echo ""

while [ -z "$model_access_key" ]
do
  read -p "Enter ${selected_provider} API key: " model_access_key
done

su - zeroclaw -c "/usr/local/bin/zeroclaw onboard --force --api-key '${model_access_key}' --provider '${onboard_provider}' --model '${onboard_model}'" > /dev/null 2>&1

# Override gateway port to match systemd service expectation
sed -i 's/^port = .*/port = 42617/' "${CONFIG_FILE}"

chown zeroclaw:zeroclaw "${CONFIG_FILE}"
chmod 0600 "${CONFIG_FILE}"

echo ""
echo "${selected_provider} key configured successfully."
echo "Starting ZeroClaw service..."
systemctl enable zeroclaw
systemctl restart zeroclaw

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
