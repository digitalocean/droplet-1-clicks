#!/bin/bash

# OpenCode First-Login Setup Wizard
# Prompts for a DigitalOcean Gradient model access key and configures OpenCode.

SETUP_MARKER="/root/.opencode_setup_complete"
CONFIG_FILE="/root/.config/opencode/opencode.json"
AUTH_FILE="/root/.local/share/opencode/auth.json"

remove_first_login_hook() {
  sed -i '/\/opt\/setup-opencode\.sh/d' /root/.bashrc 2>/dev/null || true
}

try_apply_gradient_from_env() {
  set -a
  # shellcheck source=/dev/null
  source /etc/environment 2>/dev/null || true
  set +a

  if [ -x /opt/apply-gradient-from-env.sh ] && /opt/apply-gradient-from-env.sh; then
    echo "Gradient configured from droplet environment."
    remove_first_login_hook
    return 0
  fi

  return 1
}

# Startup scripts may land in /etc/environment after 001_onboot; retry before prompting.
if [ "$1" != "--force" ] && try_apply_gradient_from_env; then
  exit 0
fi

gradient_already_configured() {
  local configured_key

  if [ -f "$SETUP_MARKER" ]; then
    echo "OpenCode setup is already complete"
    return 0
  fi

  if [ -f "$AUTH_FILE" ]; then
    configured_key=$(jq -r '.digitalocean.key // empty' "$AUTH_FILE" 2>/dev/null || true)
    if [ -n "$configured_key" ] && [ "$configured_key" != "null" ]; then
      echo "DigitalOcean Gradient is already configured"
      return 0
    fi
  fi

  return 1
}

configured_reason=$(gradient_already_configured || true)
if [ -n "$configured_reason" ] && [ "$1" != "--force" ]; then
  echo "${configured_reason}. Skipping setup wizard."
  remove_first_login_hook
  exit 0
fi

echo ""
echo "========================================================================"
echo "  OpenCode Setup - DigitalOcean Gradient AI"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured with DigitalOcean Gradient AI, which gives"
echo "you access to top coding models through a single Gradient model access key:"
echo ""
echo "  digitalocean/ (OpenAI-compatible):  GPT-5.2, GPT-5, GPT-5.1 Codex Max,"
echo "    GPT-4.1, o3, DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B, Kimi K2.5 (default),"
echo "    glm-5, MiniMax M2.5, Claude Opus 4.6, Opus 4.5, Sonnet 4.5, Sonnet 4"
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

# Write the auth.json file for the Gradient OpenAI-compatible provider.
mkdir -p /root/.local/share/opencode
cat > /root/.local/share/opencode/auth.json << EOF
{
  "digitalocean": {
    "type": "api",
    "key": "${MODEL_KEY}"
  },
  "do-anthropic": {
    "type": "api",
    "key": "${MODEL_KEY}"
  }
}
EOF
chmod 600 /root/.local/share/opencode/auth.json

# Substitute Gradient key into opencode.json (do-anthropic authToken placeholder).
if [ -f "$CONFIG_FILE" ] && grep -q '%API_TOKEN%' "$CONFIG_FILE" 2>/dev/null; then
  ESC_KEY=$(printf '%s\n' "$MODEL_KEY" | sed 's/\\/\\\\/g; s/&/\\&/g; s/|/\\|/g')
  sed -i "s|%API_TOKEN%|${ESC_KEY}|g" "$CONFIG_FILE"
fi

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

remove_first_login_hook

echo ""
echo "========================================================================"
echo "  Setup complete! OpenCode is ready to use."
echo ""
echo "  Default model: Kimi K2.5 (digitalocean/kimi-k2.5)"
echo ""
echo "  To start:  cd /path/to/your/project && opencode"
echo "  Config:    /root/.config/opencode/opencode.json"
echo "  Auth:      /root/.local/share/opencode/auth.json"
echo "  Switch models:    use /models inside OpenCode"
echo "  Other providers:  use /connect to add Anthropic, OpenAI, Google, etc."
echo "========================================================================"
echo ""
