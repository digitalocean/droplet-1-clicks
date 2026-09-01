#!/bin/bash

# Grok Build First-Login Setup Wizard
# Primary path: DigitalOcean Serverless Inference (model access key).
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
INFERENCE_MODELS_LIB="/var/lib/digitalocean/inference-models.sh"
PREFERRED_INFERENCE_MODEL="openai-gpt-5.5"

# The .bashrc hook invokes this with --autostart on login. In that mode, skip
# silently if setup is already complete or a key is configured from the
# environment. A manual run (no --autostart) always (re-)runs the wizard, so
# `/opt/setup-grok-build.sh` reconfigures any time. `--force` is accepted as an
# alias for a manual run.
if [ "${1:-}" = "--autostart" ]; then
  [ -f "$SETUP_MARKER" ] && exit 0
  if [ -x /opt/apply-inference-from-env.sh ] && /opt/apply-inference-from-env.sh >/dev/null 2>&1; then
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
echo "  Grok Build Setup - DigitalOcean Serverless Inference"
echo "========================================================================"
echo ""
echo "This droplet is pre-configured to run Grok Build on DigitalOcean Serverless"
echo "Inference (https://inference.do-ai.run/v1). A single DigitalOcean model"
echo "access key unlocks the current Serverless Inference catalog, plus the"
echo "Intelligent Inference Router."
echo ""
echo "To create a DigitalOcean model access key:"
echo "  1. Go to https://cloud.digitalocean.com/model-studio/manage-keys"
echo "  2. Or from the cloud console, navigate to Inference > Manage"
echo "  3. Click 'Create Model Access Key'"
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your DigitalOcean model access key (or press Enter for xAI options): " MODEL_ACCESS_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -n "$MODEL_ACCESS_KEY" ]; then
  if [ ! -f "$INFERENCE_MODELS_LIB" ]; then
    echo "ERROR: missing $INFERENCE_MODELS_LIB" >&2
    exit 1
  fi
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"

  save_env_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"

  echo ""
  echo "Fetching available models from DigitalOcean Serverless Inference..."

  json=""
  chat_ids=""
  CHOSEN=""
  ROUTER_NAME=""
  while true; do
    if json="$(fetch_inference_models_json "$MODEL_ACCESS_KEY")"; then
      chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
      if [ -z "$chat_ids" ]; then
        chat_ids="$(printf '%s' "$json" | parse_inference_model_ids)"
      fi
      if [ -n "$chat_ids" ]; then
        if printf '%s\n' "$chat_ids" | grep -Fxq "$PREFERRED_INFERENCE_MODEL"; then
          rest="$(printf '%s\n' "$chat_ids" | grep -Fxv "$PREFERRED_INFERENCE_MODEL")"
          chat_ids="$(printf '%s\n%s\n' "$PREFERRED_INFERENCE_MODEL" "$rest")"
        fi
        break
      fi
      echo "The serverless inference API returned no models for this key."
    else
      status="${INFERENCE_MODELS_HTTP_STATUS:-000}"
      if [ "$status" = "401" ] || [ "$status" = "403" ]; then
        echo "That key was rejected (HTTP ${status})."
      else
        echo "Could not list models from https://inference.do-ai.run/v1/models (HTTP ${status})."
      fi
    fi

    echo ""
    echo "You can re-enter the key, type a model id to use this key anyway,"
    echo "or press Enter to keep trying options."
    old_histfile="${HISTFILE-}"
    unset HISTFILE
    read -rsp "Re-enter your model access key (or press Enter to keep the current key): " NEW_KEY
    echo ""
    [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"
    if [ -n "${NEW_KEY}" ]; then
      MODEL_ACCESS_KEY="$NEW_KEY"
      save_env_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
      continue
    fi

    echo ""
    echo "Enter a DigitalOcean model id, R for the Intelligent Inference Router,"
    echo "or press Enter to try listing models again."
    read -rp "Model id / R: " MANUAL_SEL
    if [ "$MANUAL_SEL" = "R" ] || [ "$MANUAL_SEL" = "r" ]; then
      echo ""
      echo "Create a router under Inference > Routers, then enter its name."
      read -rp "Router name: " ROUTER_NAME
      if [ -n "$ROUTER_NAME" ]; then
        chat_ids=""
        break
      fi
      echo "No router name entered."
    elif [ -n "$MANUAL_SEL" ]; then
      CHOSEN="$MANUAL_SEL"
      chat_ids=""
      break
    fi
  done

  if [ -n "$chat_ids" ]; then
    default_model="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
    echo ""
    echo "Choose a default model (you can switch later with /model or -m <alias>):"
    echo ""
    i=1
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf "  %2d) %s\n" "$i" "$line"
      i=$((i + 1))
    done <<<"$chat_ids"
    echo "   R) DigitalOcean Intelligent Inference Router (auto-picks the best model)"
    echo ""
    count=$((i - 1))
    read -rp "Selection [1-${count} / R, or Enter for ${default_model}]: " SEL

    if [ "$SEL" = "R" ] || [ "$SEL" = "r" ]; then
      echo ""
      echo "Create a router under Inference > Routers, then enter its name."
      read -rp "Router name: " ROUTER_NAME
      if [ -z "$ROUTER_NAME" ]; then
        echo "No router name entered; keeping ${default_model}."
        CHOSEN="$default_model"
      fi
    elif [ -z "$SEL" ]; then
      CHOSEN="$default_model"
    elif CHOSEN="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "$SEL")"; then
      :
    elif [[ "$SEL" =~ ^[0-9]+$ ]]; then
      echo "Invalid selection; using ${default_model}."
      CHOSEN="$default_model"
    else
      CHOSEN="$SEL"
    fi
  fi

  if [ -n "$ROUTER_NAME" ]; then
    save_env_kv DO_INFERENCE_ROUTER "$ROUTER_NAME"
    echo "Default set to Intelligent Inference Router (router:${ROUTER_NAME})."
  else
    save_env_kv DO_INFERENCE_MODEL "$CHOSEN"
    save_env_kv DO_INFERENCE_ROUTER ""
    echo "Default model set to: $CHOSEN"
  fi

  export MODEL_ACCESS_KEY="$MODEL_ACCESS_KEY"
  /opt/apply-inference-from-env.sh
  finish
fi

# --- xAI account / API key fallback ---
echo ""
echo "No DigitalOcean model access key entered. You can instead use an xAI account:"
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
    /opt/apply-inference-from-env.sh
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
