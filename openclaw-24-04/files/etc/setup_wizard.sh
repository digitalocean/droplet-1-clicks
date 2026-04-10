#!/bin/bash

# OpenClaw Token Setup Script
# Run this script to configure OpenClaw with a AI API key

DROPL_IP=$(hostname -I | awk '{print$1}')
PS3="Select a provider (1-5): "
options=("GradientAI" "OpenAI" "Anthropic" "OpenRouter" "OpenClaw Model Setup")

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

echo "${selected_provider} Configuration Setup"
echo "=============================="
echo ""

if [[ "$selected_provider" == "OpenClaw Model Setup" ]]; then
  /opt/openclaw-cli.sh configure --section model
  jq -s '.[0] * .[1]' /home/openclaw/.openclaw/openclaw.json ${target_config} > /home/openclaw/.openclaw/openclaw.json.bak
  cp /home/openclaw/.openclaw/openclaw.json.bak /home/openclaw/.openclaw/openclaw.json
else
  while [ -z "$model_access_key" ]
    do
      read -p "Enter ${selected_provider} model access key: " model_access_key
    done
fi

mkdir -p /home/openclaw/.openclaw

if [[ "$selected_provider" == "GradientAI" ]]; then
    jq --arg key "$model_access_key" '.models.providers.gradient.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
elif [[ "$selected_provider" == "OpenRouter" ]] then
    jq --arg key "$model_access_key" '.models.providers.openrouter.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
elif [[ "$selected_provider" != "OpenClaw Model Setup" ]] then
    cp ${target_config} /home/openclaw/.openclaw/openclaw.json
    echo -e "\n${env_key_name}=${model_access_key}" >> /opt/openclaw.env
fi

GATEWAY_TOKEN=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

jq --arg key "${GATEWAY_TOKEN}" '.gateway.auth.token = $key' /home/openclaw/.openclaw/openclaw.json > /home/openclaw/.openclaw/openclaw.json.tmp
mv /home/openclaw/.openclaw/openclaw.json.tmp /home/openclaw/.openclaw/openclaw.json

jq --arg key "https://${DROPL_IP}" '.gateway.controlUi.allowedOrigins = [ $key ]' /home/openclaw/.openclaw/openclaw.json > /home/openclaw/.openclaw/openclaw.json.tmp
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

cp -r /usr/lib/node_modules/openclaw/skills /home/openclaw/.openclaw/workspace/

printf "\nWaiting for gateway to become ready..."

GATEWAY_READY=false
for i in $(seq 1 60); do
    HTTP_CODE=$(curl -so /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:18789/ 2>/dev/null) || true
    if [ "$HTTP_CODE" != "000" ] && [ -n "$HTTP_CODE" ]; then
        GATEWAY_READY=true
        break
    fi
    sleep 2
    printf "."
done
printf "\n"

if [ "$GATEWAY_READY" = false ]; then
    echo "⚠️ Gateway did not respond on port 18789 within 120s."
    echo "Check with: systemctl status openclaw"
fi

printf "Pairing local device...\n"

PAIR_TMPFILE=$(mktemp)
PAIR_SUCCESS=false
for attempt in $(seq 1 20); do
    /opt/openclaw-cli.sh devices list --token="${GATEWAY_TOKEN}" > "$PAIR_TMPFILE" 2>&1 || true

    OUTPUT=$(sed -n '/Pending/,/Paired/p' "$PAIR_TMPFILE")
    REQUEST_IDS=($(echo "$OUTPUT" | grep -oP '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}'))
    COUNT=${#REQUEST_IDS[@]}

    if [ "$COUNT" -ge 1 ]; then
        for rid in "${REQUEST_IDS[@]}"; do
            /opt/openclaw-cli.sh devices approve "$rid" --token="${GATEWAY_TOKEN}" > /dev/null 2>&1 || true
        done
        PAIR_SUCCESS=true
        break
    fi

    printf "Waiting for local device pairing request (%d/20)...\n" "$attempt"
    sleep 5
done
rm -f "$PAIR_TMPFILE"

if [ "$PAIR_SUCCESS" = true ]; then
    printf "\nSuccessfully paired local device\n"
else
    printf "\nFailed to pair local device\n"
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

DASHBOARD_URL="https://${DROPL_IP}"

printf '\n======================================\n'
printf '  Browser Pairing Setup\n'
printf '======================================\n\n'

printf "Open this link in your browser to start pairing:\n\n"
printf '  \e]8;;%s\e\\%s\e]8;;\e\\\n\n' "$DASHBOARD_URL" "$DASHBOARD_URL"
printf "Gateway token (paste into the dashboard):\n\n"
printf "  %s\n\n" "${GATEWAY_TOKEN}"
printf "Steps:\n"
printf "  1. Click the link above (or copy the URL into your browser)\n"
printf "  2. Paste the gateway token into the 'Gateway Token' field\n"
printf "  3. Click 'Connect'\n"
printf "  4. You will see a 'pairing required' message — this is expected\n\n"

while true; do
    read -p "Type 'continue' once you see the 'pairing required' message. (continue/exit): " yn
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

BROWSER_TMPFILE=$(mktemp)
BROWSER_PAIR_SUCCESS=false
for attempt in $(seq 1 10); do
    /opt/openclaw-cli.sh devices list --token="${GATEWAY_TOKEN}" > "$BROWSER_TMPFILE" 2>&1 || true

    OUTPUT=$(sed -n '/Pending/,/Paired/p' "$BROWSER_TMPFILE")
    REQUEST_IDS=($(echo "$OUTPUT" | grep -oP '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}'))
    COUNT=${#REQUEST_IDS[@]}

    if [ "$COUNT" -ge 1 ]; then
        printf "Pairing request(s) found (%d)...\n" "$COUNT"
        for rid in "${REQUEST_IDS[@]}"; do
            /opt/openclaw-cli.sh devices approve "$rid" --token="${GATEWAY_TOKEN}" > /dev/null 2>&1 || true
        done
        BROWSER_PAIR_SUCCESS=true
        break
    fi

    printf "No pending request yet, retrying (%d/10)...\n" "$attempt"
    sleep 5
done
rm -f "$BROWSER_TMPFILE"

if [ "$BROWSER_PAIR_SUCCESS" = true ]; then
    printf "Pairing request approved! Refresh the page to open dashboard.\n\nSetup complete. You should now be able to refresh dashboard UI and start using your OpenClaw 1-Click!\n"
    printf "🔧 You can launch OpenClaw TUI using:\n\t$ /opt/openclaw-tui.sh\n"
    cp /etc/skel/.bashrc /root
    exit 0
else
    echo "Error: No pending requests found after 10 attempts. Please proceed with manual pairing." >&2
    exit 1
fi