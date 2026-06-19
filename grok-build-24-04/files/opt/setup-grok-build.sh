#!/bin/bash

# Grok Build First-Login Setup Wizard
# Primary path: DigitalOcean Gradient serverless inference (model access key).
# Fallback: sign in with an xAI account (device-code auth) or an xAI API key.

# This script must be EXECUTED, not sourced. It calls `exit` in several places;
# if you `source` it, those run in your interactive shell and log you out.
# Detect sourcing and bail out safely (return, not exit) with a hint.
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  echo "Don't source this script -- run it:  /opt/setup-grok-build.sh" >&2
  return 1 2>/dev/null || exit 1
fi

SETUP_MARKER="/root/.grok_build_setup_complete"
ENV_FILE="/opt/grok-build.env"
CONFIG_FILE="/root/.grok/config.toml"

# The .bashrc hook invokes this with --autostart on login. In that mode, skip
# silently if setup is already complete or a key is configured from the
# environment. A manual run (no --autostart) always (re-)runs the wizard, so
# `/opt/setup-grok-build.sh` reconfigures any time. `--force` is accepted as an
# alias for a manual run.
if [ "${1:-}" = "--autostart" ]; then
  [ -f "$SETUP_MARKER" ] && exit 0
  if [ -x /opt/apply-gradient-from-env.sh ] && /opt/apply-gradient-from-env.sh >/dev/null 2>&1; then
    exit 0
  fi
fi

# Make sure grok is on PATH in this shell.
[ -d /root/.grok/bin ] && export PATH="/root/.grok/bin:$PATH"

save_env_kv() {
  local key="$1" val="$2"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || : > "${ENV_FILE}.tmp"
  printf '%s=%q\n' "$key" "$val" >> "${ENV_FILE}.tmp"
  mv "${ENV_FILE}.tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

finish() {
  # Mark setup complete. We intentionally do NOT remove the wizard hook from
  # /root/.bashrc here: editing .bashrc while the login shell is still reading
  # it can shift line offsets. Subsequent logins are skipped via SETUP_MARKER
  # (see the guard at the top), and the permanent key-env block in .bashrc
  # keeps sourcing the key into every shell.
  touch "$SETUP_MARKER"
  echo ""
  echo "========================================================================"
  echo "  Setup complete! Grok Build is ready to use."
  echo ""
  echo "  To start:  cd /path/to/your/project && grok"
  echo "  Headless:  grok -p \"Explain this codebase\""
  echo "  Switch models:  /model in the TUI, or  grok -p \"...\" -m <alias>"
  echo "  Config:    /root/.grok/config.toml"
  echo "========================================================================"
  echo ""
  exit 0
}

echo ""
echo "========================================================================"
echo "  Grok Build Setup - DigitalOcean Gradient AI"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured to run Grok Build on DigitalOcean Gradient"
echo "serverless inference (https://inference.do-ai.run/v1). A single Gradient"
echo "model access key unlocks GPT-5.5 (default), Claude, Llama, Kimi, GLM,"
echo "DeepSeek, Qwen, MiniMax and more, plus the Intelligent Inference Router."
echo ""
echo "To create a DigitalOcean model access key:"
echo "  1. Go to https://cloud.digitalocean.com/model-studio/manage-keys"
echo "  2. Or from the cloud console, navigate to Inference > Manage"
echo "  3. Click 'Create Model Access Key'"
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your Gradient model access key (or press Enter for xAI options): " GRADIENT_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

# DigitalOcean Gradient model menu (alias -> label): a short list of the latest,
# most popular coding models. The full catalog lives in /root/.grok/config.toml
# and can be selected any time with /model or -m <alias>.
MENU_ALIASES=(
  gpt-5-5 gpt-5-3-codex claude-opus-4-8 claude-sonnet-4-6
  deepseek-v4-pro kimi-k2-6 qwen3-coder-flash glm-5
)
MENU_LABELS=(
  "GPT-5.5 (default)" "GPT-5.3 Codex" "Claude Opus 4.8" "Claude Sonnet 4.6"
  "DeepSeek V4 Pro" "Kimi K2.6" "Qwen3 Coder Flash" "GLM-5"
)

if [ -n "$GRADIENT_KEY" ]; then
  save_env_kv GRADIENT_KEY "$GRADIENT_KEY"

  echo ""
  echo "Choose a default model (you can switch later with /model or -m <alias>):"
  echo ""
  for i in "${!MENU_ALIASES[@]}"; do
    printf "  %2d) %-22s (%s)\n" "$((i + 1))" "${MENU_LABELS[$i]}" "${MENU_ALIASES[$i]}"
  done
  echo "   R) DigitalOcean Intelligent Inference Router (auto-picks the best model)"
  echo ""
  read -rp "Selection [1-${#MENU_ALIASES[@]} / R, or Enter for GPT-5.5]: " SEL

  if [ "$SEL" = "R" ] || [ "$SEL" = "r" ]; then
    echo ""
    echo "Create a router under Gradient > Inference > Routers, then enter its name."
    read -rp "Router name: " ROUTER_NAME
    if [ -n "$ROUTER_NAME" ]; then
      save_env_kv GRADIENT_ROUTER "$ROUTER_NAME"
    else
      echo "No router name entered; keeping the GPT-5.5 default."
      save_env_kv GRADIENT_MODEL "gpt-5-5"
    fi
  elif [ -n "$SEL" ] && [ "$SEL" -ge 1 ] 2>/dev/null && [ "$SEL" -le "${#MENU_ALIASES[@]}" ] 2>/dev/null; then
    CHOSEN="${MENU_ALIASES[$((SEL - 1))]}"
    save_env_kv GRADIENT_MODEL "$CHOSEN"
    save_env_kv GRADIENT_ROUTER ""
    echo "Default model set to: $CHOSEN"
  else
    save_env_kv GRADIENT_MODEL "gpt-5-5"
    save_env_kv GRADIENT_ROUTER ""
    echo "Default model set to: gpt-5-5 (GPT-5.5)"
  fi

  /opt/apply-gradient-from-env.sh
  export MODEL_ACCESS_KEY="$GRADIENT_KEY"

  echo ""
  echo "Testing connection to DigitalOcean Gradient..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${GRADIENT_KEY}" \
    https://inference.do-ai.run/v1/models 2>/dev/null)
  if [ "$HTTP_STATUS" = "200" ]; then
    echo "Connection successful! Your key is valid."
  else
    echo "Warning: received HTTP $HTTP_STATUS from the Gradient API."
    echo "Your key was saved. If it's wrong, re-run: /opt/setup-grok-build.sh"
  fi
  finish
fi

# --- xAI account / API key fallback ---
echo ""
echo "No Gradient key entered. You can instead use an xAI account:"
echo ""
echo "  1) Sign in with your xAI account (device-code auth)"
echo "     For SuperGrok / X Premium+ subscribers. You'll get a code + URL."
echo "  2) Enter an xAI API key (XAI_API_KEY) from https://console.x.ai"
echo ""
read -rp "Choose [1/2] or press Enter to skip: " CHOICE

case "$CHOICE" in
  1)
    echo ""
    echo "Launching device-code sign-in. Follow the on-screen URL and code..."
    echo ""
    if grok login --device-auth; then
      sed -i 's|^\([[:space:]]*default[[:space:]]*=[[:space:]]*\).*|\1"grok-build"|' "$CONFIG_FILE" 2>/dev/null || true
      echo ""
      echo "Signed in successfully. Default model set to grok-build-0.1."
      finish
    else
      echo ""
      echo "Sign-in did not complete. Retry later with: grok login --device-auth"
      exit 0
    fi
    ;;
  2)
    echo ""
    old_histfile="${HISTFILE-}"
    unset HISTFILE
    read -rsp "Enter your xAI API key (xai-...): " API_KEY
    echo ""
    [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"
    if [ -z "$API_KEY" ]; then
      echo "No key entered. Setup skipped."
      exit 0
    fi
    save_env_kv XAI_API_KEY "$API_KEY"
    /opt/apply-gradient-from-env.sh
    export XAI_API_KEY="$API_KEY"
    echo "xAI API key saved. Default model set to grok-build-0.1."
    finish
    ;;
  *)
    echo ""
    echo "Setup skipped. Configure later by running: /opt/setup-grok-build.sh"
    echo ""
    echo "Note: this droplet has no desktop browser, so do NOT run a bare"
    echo "'grok login' (it would try to open one). To sign in with an xAI"
    echo "account without a browser, use device-code auth:"
    echo "  /opt/grok-login.sh      (or: grok login --device-auth)"
    echo ""
    echo "To use a different model provider (OpenAI, xAI, Anthropic, or any"
    echo "OpenAI-compatible endpoint), see the commented examples and steps in:"
    echo "  /root/.grok/config.toml"
    echo "Then run 'grok inspect' to confirm what Grok loaded."
    echo ""
    exit 0
    ;;
esac
