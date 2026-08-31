#!/bin/bash

# OpenCode First-Login Setup Wizard
# Prompts for a DigitalOcean Gradient model access key and configures OpenCode.

SETUP_MARKER="/root/.opencode_setup_complete"
CONFIG_FILE="/root/.config/opencode/opencode.json"
AUTH_FILE="/root/.local/share/opencode/auth.json"
ENV_FILE="/opt/opencode.env"

remove_first_login_hook() {
  sed -i '/\/opt\/setup-opencode\.sh/d' /root/.bashrc 2>/dev/null || true
}

save_env_kv() {
  local key="$1" val="$2"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || : > "${ENV_FILE}.tmp"
  printf '%s=%q\n' "$key" "$val" >> "${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
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
echo "  digitalocean/ (OpenAI-compatible):  GPT-5.2, GPT-5, GPT-4.1, o3,"
echo "    DeepSeek R1 70B, Qwen3 32B, Llama 3.3 70B, Kimi K2.5,"
echo "    glm-5, MiniMax M2.5 (default), Claude Opus 4.6, Opus 4.5,"
echo "    Sonnet 4.5, Sonnet 4, plus the Intelligent Inference Router."
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

save_env_kv GRADIENT_KEY "$MODEL_KEY"
export GRADIENT_KEY="$MODEL_KEY"

# Short list of the latest, most popular coding models. The full catalog lives
# in /root/.config/opencode/opencode.json and can be selected any time with /models.
MENU_IDS=(
  minimax-m2.5 kimi-k2.5 openai-gpt-5.2 openai-gpt-5
  glm-5 llama3.3-70b-instruct alibaba-qwen3-32b deepseek-r1-distill-llama-70b
)
MENU_LABELS=(
  "MiniMax M2.5 (default)" "Kimi K2.5" "GPT-5.2" "GPT-5"
  "glm-5" "Llama 3.3 70B Instruct" "Qwen3 32B" "DeepSeek R1 Distill Llama 70B"
)

echo ""
echo "Choose a default model (you can switch later with /models):"
echo ""
for i in "${!MENU_IDS[@]}"; do
  printf "  %2d) %-28s (%s)\n" "$((i + 1))" "${MENU_LABELS[$i]}" "${MENU_IDS[$i]}"
done
echo "   R) DigitalOcean Intelligent Inference Router (auto-picks the best model)"
echo ""
read -rp "Selection [1-${#MENU_IDS[@]} / R, or Enter for MiniMax M2.5]: " SEL

CHOSEN_LABEL="MiniMax M2.5 (digitalocean/minimax-m2.5)"

if [ "$SEL" = "R" ] || [ "$SEL" = "r" ]; then
  echo ""
  echo "Create a router under Inference > Routers, then enter its name."
  read -rp "Router name: " ROUTER_NAME
  if [ -n "$ROUTER_NAME" ]; then
    ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
    ROUTER_NAME="${ROUTER_NAME#router:}"
    save_env_kv DO_INFERENCE_ROUTER "$ROUTER_NAME"
    export DO_INFERENCE_ROUTER="$ROUTER_NAME"
    CHOSEN_LABEL="Intelligent Inference Router (digitalocean/router:${ROUTER_NAME})"
  else
    echo "No router name entered; keeping the MiniMax M2.5 default."
    save_env_kv GRADIENT_MODEL "minimax-m2.5"
    save_env_kv DO_INFERENCE_ROUTER ""
    export DO_INFERENCE_ROUTER=""
  fi
elif [ -n "$SEL" ] && [ "$SEL" -ge 1 ] 2>/dev/null && [ "$SEL" -le "${#MENU_IDS[@]}" ] 2>/dev/null; then
  CHOSEN="${MENU_IDS[$((SEL - 1))]}"
  save_env_kv GRADIENT_MODEL "$CHOSEN"
  save_env_kv DO_INFERENCE_ROUTER ""
  export GRADIENT_MODEL="$CHOSEN"
  export DO_INFERENCE_ROUTER=""
  echo "Default model set to: $CHOSEN"
  CHOSEN_LABEL="${MENU_LABELS[$((SEL - 1))]} (digitalocean/${CHOSEN})"
else
  save_env_kv GRADIENT_MODEL "minimax-m2.5"
  save_env_kv DO_INFERENCE_ROUTER ""
  export DO_INFERENCE_ROUTER=""
  echo "Default model set to: minimax-m2.5 (MiniMax M2.5)"
fi

/opt/apply-gradient-from-env.sh

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
echo "  Default model: ${CHOSEN_LABEL}"
echo ""
echo "  To start:  cd /path/to/your/project && opencode"
echo "  Config:    /root/.config/opencode/opencode.json"
echo "  Auth:      /root/.local/share/opencode/auth.json"
echo "  Switch models:    use /models inside OpenCode"
echo "  Other providers:  use /connect to add Anthropic, OpenAI, Google, etc."
echo "========================================================================"
echo ""
