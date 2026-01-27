#!/bin/bash

# Create minimal Clawdbot config if it doesn't exist
if [ ! -f "/home/clawdbot/.clawdbot/clawdbot.json" ]; then
    echo "Creating minimal Clawdbot configuration..."
    mkdir -p /home/clawdbot/.clawdbot

    while [ -z $model_access_key ]
      do
        echo -en "\n"
        read -p "Enter GradientAI model access key: " model_access_key
      done

    jq --arg key "$model_access_key" '.models.providers.digitalocean.apiKey = $key' /etc/config/clawdbot.json > /home/clawdbot/.clawdbot/clawdbot.json
    chown clawdbot:clawdbot /home/clawdbot/.clawdbot/clawdbot.json
    chmod 644 /home/clawdbot/.clawdbot/clawdbot.json
fi

# Start the Clawdbot service
echo "Starting Clawdbot Gateway service..."
systemctl start clawdbot

# Wait for service to start
sleep 3

# Display status
if systemctl is-active --quiet clawdbot; then
    echo "✅ Clawdbot Gateway started successfully!"
else
    echo "⚠️  Clawdbot service may need configuration. Check with: systemctl status clawdbot"
fi


cp /etc/skel/.bashrc /root

echo "Initialization complete."
