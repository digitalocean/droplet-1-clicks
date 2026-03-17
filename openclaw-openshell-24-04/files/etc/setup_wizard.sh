#!/bin/bash
# OpenClaw OpenShell setup wizard: GradientAI API key and model selection

set -e
DROPL_IP=$(hostname -I | awk '{print$1}')

echo "--- OpenClaw OpenShell Setup (GradientAI) ---"
read -rp "Enter your GradientAI API key: " GRADIENT_API_KEY
if [ -z "$GRADIENT_API_KEY" ]; then
    echo "API key cannot be empty."
    exit 1
fi

echo ""
echo "Select a model (enter number):"
echo "  1) anthropic-claude-4.5-sonnet (Claude 4.5 Sonnet)"
echo "  2) anthropic-claude-4.5-opus (Claude 4.5 Opus)"
echo "  3) Other (enter model id when prompted)"
read -rp "Choice [1]: " MODEL_CHOICE
MODEL_CHOICE=${MODEL_CHOICE:-1}

case "$MODEL_CHOICE" in
    1) MODEL_ID="anthropic-claude-4.5-sonnet"; MODEL_NAME="Claude 4.5 Sonnet" ;;
    2) MODEL_ID="anthropic-claude-4.5-opus"; MODEL_NAME="Claude 4.5 Opus" ;;
    3)
        read -rp "Enter Gradient model id: " MODEL_ID
        MODEL_NAME="$MODEL_ID"
        ;;
    *) MODEL_ID="anthropic-claude-4.5-sonnet"; MODEL_NAME="Claude 4.5 Sonnet" ;;
esac

openshell provider create \
  --name do-gradient \
  --type openai --credential \
  OPENAI_API_KEY=$GRADIENT_API_KEY \
  --config OPENAI_BASE_URL=https://inference.do-ai.run/v1

openshell inference set --provider do-gradient --model $MODEL_ID

# Start from existing /etc/config/openclaw.json (token already set by onboot), only set API key and model id/name
CONFIG_FILE="/tmp/openclaw.json.tmp"
jq \
    --arg modelId "$MODEL_ID" \
    --arg modelName "$MODEL_NAME" \
    --arg origin "https://${DROPL_IP}" \
    '
    .models.providers.openshell.models[0].id = $modelId |
    .models.providers.openshell.models[0].name = $modelName |
    .agents.defaults.model.primary = ("openshell/" + $modelId) |
    .agents.defaults.models |= (. + { ("openshell/" + $modelId): { "params": { "maxTokens": 64000 } } }) |
    .gateway.controlUi.allowedOrigins = [$origin]
    ' /etc/config/openclaw.json > "$CONFIG_FILE"
mv "$CONFIG_FILE" /tmp/openclaw.json
CONFIG_FILE="/tmp/openclaw.json"

# Upload config into OpenShell sandbox (per instructions: openshell sandbox upload <NAME> <LOCAL_PATH> [DEST])
openshell sandbox upload openclaw-sandbox "$CONFIG_FILE" /home/openclaw/.openclaw/openclaw.json || true

# Restart sandbox to pick up config
systemctl enable openclaw-sandbox

# Remove wizard from .bashrc so it runs only once
sed -i '/\/etc\/setup_wizard.sh/d' /root/.bashrc 2>/dev/null || true

echo ""
echo "Setup complete. GradientAI configured with model: $MODEL_NAME"
echo "Dashboard: https://${DROPL_IP} (use gateway token from MOTD or /opt/openclaw.env)"
