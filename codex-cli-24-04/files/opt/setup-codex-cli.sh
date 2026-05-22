#!/bin/bash

# Codex CLI First-Login Setup Wizard
# Prompts for a DigitalOcean Gradient model access key and configures Codex.

SETUP_MARKER="/root/.codex_setup_complete"
ENV_FILE="/opt/codex-cli.env"

if [ -f "$SETUP_MARKER" ] && [ "$1" != "--force" ]; then
  if ! grep -q '/opt/setup-codex-cli.sh' /root/.bashrc 2>/dev/null; then
    exit 0
  fi
  rm -f "$SETUP_MARKER"
fi

if [ "$1" != "--force" ] && [ -x /opt/apply-gradient-from-env.sh ]; then
  if /opt/apply-gradient-from-env.sh; then
    exit 0
  fi
fi

echo ""
echo "========================================================================"
echo "  Codex CLI Setup - DigitalOcean Gradient AI"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured with DigitalOcean Gradient AI for inference."
echo "Codex CLI routes requests through https://inference.do-ai.run/v1."
echo ""
echo "Available models include GPT-5.5 (default), GPT-5.2, GPT-5.1 Codex Max, GPT-5,"
echo "GPT-4.1, o3, DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B, Kimi K2.5,"
echo "glm-5, MiniMax M2.5, and Claude Opus/Sonnet models."
echo ""
echo "To create a Gradient model access key:"
echo "  1. Go to https://cloud.digitalocean.com/gen-ai"
echo "  2. Navigate to API Keys > Model Access Keys"
echo "  3. Click 'Create Model Access Key'"
echo ""
echo "Alternatively, set GRADIENT_KEY in /opt/codex-cli.env or as a droplet"
echo "environment variable and reboot, or run: /opt/apply-gradient-from-env.sh"
echo ""

read -p "Enter your Gradient model access key (or press Enter to skip): " MODEL_KEY

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "Setup skipped. You can configure your key later by running:"
  echo "  /opt/setup-codex-cli.sh"
  echo "  or set GRADIENT_KEY in /opt/codex-cli.env and run /opt/apply-gradient-from-env.sh"
  echo ""
  exit 0
fi

touch "$ENV_FILE"
grep -v '^GRADIENT_KEY=' "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || : > "${ENV_FILE}.tmp"
printf 'GRADIENT_KEY=%q\n' "$MODEL_KEY" >> "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

/opt/apply-gradient-from-env.sh

echo ""
echo "========================================================================"
echo "  Setup complete! Codex CLI is ready to use."
echo ""
echo "  Default model: GPT-5.5 (openai-gpt-5.5)"
echo ""
echo "  To start:  cd /path/to/your/project && codex"
echo "  Config:    /root/.codex/config.toml"
echo "  API key:   /etc/profile.d/codex-gradient.sh (MODEL_ACCESS_KEY)"
echo "  Switch models:  codex -m \"openai-gpt-5.1-codex-max\" or /model inside Codex"
echo ""
echo "  ChatGPT subscription auth: run 'codex login' for OAuth instead."
echo "========================================================================"
echo ""
