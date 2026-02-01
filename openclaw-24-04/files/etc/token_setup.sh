#!/bin/bash

# OpenClaw Token Setup Script
# Run this script to configure OpenClaw with an AI API key

PS3="Select a provider (1-3): "
options=("GradientAI" "OpenAI (Coming soon!)" "Anthropic")

selected_provider="n/a"
target_config="n/a"
echo "--- AI Provider Selector ---"

select opt in "${options[@]}"
do
  case $opt in
    "GradientAI")
        selected_provider="GradientAI"
        target_config="/etc/config/gradientai.json"
        echo "You selected DigitalOcean GradientAI."
        break
        ;;
    "OpenAI")
        selected_provider="OpenAI"
        target_config="/etc/config/openai.json"
        env_key_name="OPENAI_API_KEY"
        echo "You selected OpenAI."
        break
        ;;
    "Anthropic")
        selected_provider="Anthropic"
        target_config="/etc/config/anthropic.json"
        env_key_name="ANTHROPIC_API_KEY"
        echo "You selected Anthropic."
        break
        ;;
    *)
        echo "Invalid option. Please try again."
        ;;
  esac
done

echo "${selected_provider} Configuration Setup"
echo "=============================="
echo ""

while [ -z "$model_access_key" ]
  do
    read -p "Enter ${selected_provider} model access key: " model_access_key
  done

mkdir -p /home/openclaw/.openclaw

if [[ "$selected_provider" == "GradientAI" ]]; then
    jq --arg key "$model_access_key" '.models.providers.digitalocean.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
else
    cp ${target_config} /home/openclaw/.openclaw/openclaw.json
    echo -e "\n${env_key_name}=${model_access_key}" >> /opt/openclaw.env
fi

chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 644 /home/openclaw/.openclaw/openclaw.json

echo ""
echo "${selected_provider} key configured successfully."
echo "Restarting OpenClaw service..."
systemctl restart openclaw

sleep 2

if systemctl is-active --quiet openclaw; then
    echo "✅ OpenClaw restarted successfully!"
else
    echo "⚠️ Service may need attention. Check with: systemctl status openclaw"
fi

cp /etc/skel/.bashrc /root
