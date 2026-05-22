#!/bin/bash

# Codex CLI First-Login Setup Wizard
# Prompts for a DigitalOcean Gradient model access key and configures Codex.

SETUP_MARKER="/root/.codex_setup_complete"
ENV_FILE="/root/.codex/env"

if [ -f "$SETUP_MARKER" ] && [ "$1" != "--force" ]; then
  if grep -q '/opt/setup-codex-cli.sh' /root/.bashrc 2>/dev/null; then
    exit 0
  fi
  rm -f "$SETUP_MARKER"
fi

echo ""
echo "========================================================================"
echo "  Codex CLI Setup - DigitalOcean Gradient AI"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured with DigitalOcean Gradient AI for inference."
echo "Codex CLI routes requests through https://inference.do-ai.run/v1."
echo ""
echo "Available models include GPT-5.1 Codex Max (default), GPT-5.2, GPT-5,"
echo "GPT-4.1, o3, DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B, Kimi K2.5,"
echo "glm-5, MiniMax M2.5, and Claude Opus/Sonnet models."
echo ""
echo "To create a Gradient model access key:"
echo "  1. Go to https://cloud.digitalocean.com/gen-ai"
echo "  2. Navigate to API Keys > Model Access Keys"
echo "  3. Click 'Create Model Access Key'"
echo ""

read -p "Enter your Gradient model access key (or press Enter to skip): " MODEL_KEY

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Setup skipped. You can configure your key later by running:"
  echo "  /opt/setup-codex-cli.sh"
  echo ""
  exit 0
fi

mkdir -p /root/.codex
cat > "$ENV_FILE" << EOF
export MODEL_ACCESS_KEY="${MODEL_KEY}"
EOF
chmod 600 "$ENV_FILE"

# Source the key in future login shells
if ! grep -q '/root/.codex/env' /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc << 'EOM'

# Codex CLI Gradient model access key
if [ -f /root/.codex/env ]; then
  . /root/.codex/env
fi
EOM
fi

# Export for this session
# shellcheck disable=SC1090
. "$ENV_FILE"

echo ""
echo "Testing connection to DigitalOcean Gradient..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${MODEL_KEY}" \
  -H "Content-Type: application/json" \
  https://inference.do-ai.run/v1/models 2>/dev/null)

if [ "$HTTP_STATUS" = "200" ]; then
  echo "Connection successful! Your key is valid."
else
  echo "Warning: Received HTTP $HTTP_STATUS from the Gradient API."
  echo "Your key has been saved. If it's incorrect, re-run: /opt/setup-codex-cli.sh"
fi

touch "$SETUP_MARKER"
sed -i '/\/opt\/setup-codex-cli.sh/d' /root/.bashrc

echo ""
echo "========================================================================"
echo "  Setup complete! Codex CLI is ready to use."
echo ""
echo "  Default model: GPT-5.1 Codex Max (openai-gpt-5.1-codex-max)"
echo ""
echo "  To start:  cd /path/to/your/project && codex"
echo "  Config:    /root/.codex/config.toml"
echo "  API key:   /root/.codex/env (MODEL_ACCESS_KEY)"
echo "  Switch models:  codex -m \"openai-gpt-5.2\" or /model inside Codex"
echo ""
echo "  ChatGPT subscription auth: run 'codex login' for OAuth instead."
echo "========================================================================"
echo ""
