#!/bin/bash

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
        echo "Configured models include Llama 3.3 70B, DeepSeek R1 Distill Llama 70B, GPT OSS 120B, Claude 4.5 Sonnet, MiniMax M2.5, Kimi K2.5, and GLM 5 (full list: /etc/config/gradientai.json)."
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

GATEWAY_TOKEN=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2-)

jq --arg key "${GATEWAY_TOKEN}" '.gateway.auth.token = $key' /home/openclaw/.openclaw/openclaw.json > /home/openclaw/.openclaw/openclaw.json.tmp
mv /home/openclaw/.openclaw/openclaw.json.tmp /home/openclaw/.openclaw/openclaw.json

# Control UI Origin must match the URL users type in the browser (usually public IP).
jq \
  --arg pub "${DROPL_PUBLIC_IP}" \
  --arg prv "${DROPL_PRIVATE_IP}" \
  '.gateway.controlUi.allowedOrigins = (
      if ($pub != "" and $pub != $prv) then
        ["https://" + $pub, "http://" + $pub, "https://" + $prv, "http://" + $prv]
      elif ($pub != "") then
        ["https://" + $pub, "http://" + $pub]
      else
        ["https://" + $prv, "http://" + $prv]
      end
    )' /home/openclaw/.openclaw/openclaw.json > /home/openclaw/.openclaw/openclaw.json.tmp
mv /home/openclaw/.openclaw/openclaw.json.tmp /home/openclaw/.openclaw/openclaw.json

echo "gateway.controlUi.allowedOrigins -> $(jq -c '.gateway.controlUi.allowedOrigins' /home/openclaw/.openclaw/openclaw.json)"
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

# Pending device requests only appear after a client connects (e.g. Control UI in the browser step below).

printf "\nSince version 1.26 OpenClaw requires pairing the Control UI (dashboard) before it can be used.\n"
printf "The next steps open the dashboard in your browser and approve the pending request.\n"
printf "If you still see \"pairing required\" after connecting, run (as root):\n"
printf "  sudo /opt/openclaw-approve-ui-pairing.sh\n"
printf "Documentation: %s\n" "${DOCS_MAIN}"

while true; do
    read -p "Do you want to run pairing automation now? (yes/no): " yn
    case "${yn,,}" in
        yes|y )
            echo "Proceeding with pairing automation..."
            break
            ;;
        no|n )
            echo "OpenClaw setup complete! Happy clawing!"
            echo "Docs: ${DOCS_MAIN} | ${DOCS_OPENAI}"

            cp /etc/skel/.bashrc /root
            exit 0
            ;;
        * )
            echo "Invalid input. Please type 'yes' or 'no'."
            ;;
    esac
done

DASHBOARD_URL="https://${DASHBOARD_HOST}"

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
            echo "Docs: ${DOCS_MAIN} | ${DOCS_OPENAI}"
            remove_first_login_hook
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
    REQUEST_IDS=($(echo "$OUTPUT" | grep -oE '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}' || true))
    COUNT=${#REQUEST_IDS[@]}

    if [ "$COUNT" -ge 1 ]; then
        printf "Pairing request(s) found (%d)...\n" "$COUNT"
        APPROVE_FAILED=false
        for rid in "${REQUEST_IDS[@]}"; do
            if ! /opt/openclaw-cli.sh devices approve "$rid" --token="${GATEWAY_TOKEN}" > /dev/null 2>&1; then
                APPROVE_FAILED=true
            fi
        done
        if [ "$APPROVE_FAILED" = true ]; then
            printf "Approval command failed; gateway may still be starting.\n"
            BROWSER_PAIR_SUCCESS=false
        else
            BROWSER_PAIR_SUCCESS=true
        fi
        break
    fi

    printf "No pending request yet, retrying (%d/10)...\n" "$attempt"
    sleep 5
done
rm -f "$BROWSER_TMPFILE"

if [ "$BROWSER_PAIR_SUCCESS" = true ]; then
    printf "Pairing request approved! Refresh the page to open dashboard.\n\nSetup complete. You should now be able to refresh dashboard UI and start using your OpenClaw 1-Click!\n"
    printf "🔧 You can launch OpenClaw TUI using:\n\t$ /opt/openclaw-tui.sh\n"
    printf "\nDocumentation:\n  %s\n  %s\n" "${DOCS_MAIN}" "${DOCS_OPENAI}"
    cp /etc/skel/.bashrc /root
    exit 0
else
    echo "Error: No pending requests found after 10 attempts." >&2
    echo "" >&2
    echo "Manual Control UI pairing:" >&2
    echo "  1. Keep the dashboard open at ${DASHBOARD_URL}" >&2
    echo "  2. Ensure the gateway token is pasted and you clicked Connect." >&2
    echo "  3. As root, run:  sudo /opt/openclaw-approve-ui-pairing.sh" >&2
    echo "     (Or: /opt/openclaw-cli.sh devices list --token=\"...\" then devices approve <id>)" >&2
    echo "  4. Refresh the browser." >&2
    echo "" >&2
    echo "Docs: ${DOCS_MAIN}" >&2
    remove_first_login_hook
    exit 0
fi
