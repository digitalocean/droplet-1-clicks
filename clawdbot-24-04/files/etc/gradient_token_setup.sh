#!/bin/bash

# GradientAI Setup Script
# Run this script to configure Clawdbot with a GradientAI API key

echo "GradientAI Configuration Setup"
echo "=============================="
echo ""

while [ -z "$model_access_key" ]
  do
    read -p "Enter GradientAI model access key: " model_access_key
  done

if [ ! -f "/home/clawdbot/.clawdbot/clawdbot.json" ]; then
    echo "Creating Clawdbot configuration with GradientAI..."
    mkdir -p /home/clawdbot/.clawdbot
    jq --arg key "$model_access_key" '.models.providers.digitalocean.apiKey = $key' /etc/config/clawdbot.json > /home/clawdbot/.clawdbot/clawdbot.json
else
    echo "Updating existing configuration with GradientAI key..."
    jq --arg key "$model_access_key" '.models.providers.digitalocean.apiKey = $key' /home/clawdbot/.clawdbot/clawdbot.json > /tmp/clawdbot.json.tmp
    mv /tmp/clawdbot.json.tmp /home/clawdbot/.clawdbot/clawdbot.json
fi

chown clawdbot:clawdbot /home/clawdbot/.clawdbot/clawdbot.json
chmod 644 /home/clawdbot/.clawdbot/clawdbot.json

echo ""
echo "GradientAI key configured successfully."
echo "Restarting Clawdbot service..."
systemctl restart clawdbot

sleep 2

if systemctl is-active --quiet clawdbot; then
    echo "✅ Clawdbot restarted successfully!"
else
    echo "⚠️  Service may need attention. Check with: systemctl status clawdbot"
fi
