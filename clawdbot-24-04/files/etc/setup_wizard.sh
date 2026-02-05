#!/bin/bash

# OpenClaw Token Setup Script
# Run this script to configure OpenClaw with a AI API key

PS3="Select a provider (1-3): "
options=("GradientAI" "OpenAI" "Anthropic")

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
    jq --arg key "$model_access_key" '.models.providers.gradient.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
else
    cp ${target_config} /home/openclaw/.openclaw/openclaw.json
    echo -e "\n${env_key_name}=${model_access_key}" >> /opt/openclaw.env
fi

GATEWAY_TOKEN=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

jq --arg key "${GATEWAY_TOKEN}" '.gateway.auth.token = $key' /home/openclaw/.openclaw/openclaw.json > /home/openclaw/.openclaw/openclaw.json.tmp

mv /home/openclaw/.openclaw/openclaw.json.tmp /home/openclaw/.openclaw/openclaw.json

chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 0600 /home/openclaw/.openclaw/openclaw.json

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

printf "\nSince version 1.26 OpenClaw requires manual pairing to allow access to UI dashboard.\n"

while true; do
    read -p "Do you want to run pairing automation now? (yes/no): " yn
    case "${yn,,}" in
        yes|y )
            echo "Proceeding with pairing automation..."
            break
            ;;
        no|n )
            echo "OpenClaw setup complete! Happy clawing!"

            cp /etc/skel/.bashrc /root
            exit 0
            ;;
        * )
            echo "Invalid input. Please type 'yes' or 'no'."
            ;;
    esac
done

DROPL_IP=$(hostname -I | awk '{print$1}')

printf "\nPlease open UI dashboard in your browser to trigger pairing process.\nYou will see a pairing error, but don't worry, it is expected:\n\t> https://${DROPL_IP}?token=${GATEWAY_TOKEN}\n\n"

while true; do
    read -p "Type continue once you see a pairing error on dashboard UI. (continue/exit): " yn
    case "${yn,,}" in
        continue|c )
            printf "\nSearching pairing request..."
            break
            ;;
        exit|e )
            echo "OpenClaw setup complete! Happy clawing!"
            exit 0
            ;;
        * )
            echo "Invalid input. Please type 'continue' or 'exit'."
            ;;
    esac
done

OUTPUT=$(/opt/openclaw-cli.sh devices list --token=${GATEWAY_TOKEN} | sed -n '/Pending/,/Paired/p')

REQUEST_IDS=($(echo "$OUTPUT" | grep -oP '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}'))

# 3. Count the IDs found
COUNT=${#REQUEST_IDS[@]}

if [ "$COUNT" -eq 1 ]; then
    # Return the single Request ID
    printf "Pairing request found!...\n"
    /opt/openclaw-cli.sh devices approve "${REQUEST_IDS[0]}" --token=${GATEWAY_TOKEN}
    printf "Pairing request approved!\n\nSetup complete. You should now be able to refresh dashboard UI and start using your OpenClaw 1-Click!\n"

    cp /etc/skel/.bashrc /root
    exit 0
elif [ "$COUNT" -eq 0 ]; then
    echo "Error: No pending requests found. Please proceed with manual pairing." >&2
    exit 1
else
    echo "Error: Multiple pending requests found ($COUNT). Manual intervention required." >&2
    printf "\nMultiple pending requests means other parties are trying to connect to your dashboard UI.\nThe script cannot distinguish your request from other parties."
    exit 1
fi

cp /etc/skel/.bashrc /root