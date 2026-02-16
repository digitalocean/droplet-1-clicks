#!/bin/bash

# OpenCode First-Login Setup Wizard
# Prompts for a DigitalOcean Gradient model access key and configures OpenCode.

SETUP_MARKER="/root/.opencode_setup_complete"

# Allow re-running manually; only auto-skip when called from .bashrc
if [ -f "$SETUP_MARKER" ] && [ "$1" != "--force" ]; then
  # Check if we were invoked from .bashrc (non-interactive re-trigger)
  # If the user ran this script directly, always allow it
  if grep -q '/opt/setup-opencode.sh' /root/.bashrc 2>/dev/null; then
    exit 0
  fi
  # Script was run manually -- remove the marker and continue
  rm -f "$SETUP_MARKER"
fi

echo ""
echo "========================================================================"
echo "  OpenCode Setup - DigitalOcean Gradient AI"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured with DigitalOcean Gradient AI, which gives"
echo "you access to top coding models through a single Gradient model access key:"
echo ""
echo "  Anthropic:    Claude Opus 4.6, Opus 4.5, Sonnet 4.5 (default), Sonnet 4, 3.7 Sonnet"
echo "  OpenAI:       GPT-5.2, GPT-5, GPT-5.1 Codex Max, GPT-4.1, o3"
echo "  Open Source:  DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B"
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
  echo "  /opt/setup-opencode.sh"
  echo ""
  # Don't mark complete so it runs again next login
  exit 0
fi

# Write the auth.json file
mkdir -p /root/.local/share/opencode
cat > /root/.local/share/opencode/auth.json << EOF
{
  "digitalocean": {
    "type": "api",
    "key": "${MODEL_KEY}"
  }
}
EOF
chmod 600 /root/.local/share/opencode/auth.json

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
  echo "Your key has been saved. If it's incorrect, re-run: /opt/setup-opencode.sh"
fi

# Mark setup as complete
touch "$SETUP_MARKER"

# Remove setup hook from .bashrc
sed -i '/\/opt\/setup-opencode.sh/d' /root/.bashrc

echo ""
echo "========================================================================"
echo "  Setup complete! OpenCode is ready to use."
echo ""
echo "  Default model: Claude Sonnet 4.5 (via DigitalOcean Gradient)"
echo ""
echo "  To start:  cd /path/to/your/project && opencode"
echo "  Config:    /root/.config/opencode/opencode.json"
echo "  Switch models:    use /models inside OpenCode"
echo "  Other providers:  use /connect to add Anthropic, OpenAI, Google, etc."
echo "========================================================================"
echo ""
