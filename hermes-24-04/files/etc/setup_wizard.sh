#!/bin/bash
set -euo pipefail

SETUP_DONE_MARKER=/home/hermes/.hermes/provider-configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

run_builtin_hermes_setup() {
  if [ ! -x /home/hermes/.local/bin/hermes ]; then
    echo "ERROR: Hermes CLI is not installed at /home/hermes/.local/bin/hermes." >&2
    exit 1
  fi

  su - hermes -c 'cd /home/hermes/workspace && HERMES_HOME=/home/hermes/.hermes /home/hermes/.local/bin/hermes setup'

  printf '%s\n' "configured" > "$SETUP_DONE_MARKER"
  chown hermes:hermes "$SETUP_DONE_MARKER"
  chmod 0600 "$SETUP_DONE_MARKER"
}

finish_setup() {
  remove_first_login_hook

  cat <<'EOF'

Hermes Agent setup finished.

Start chatting:
  hermes

Change model later:
  hermes model

Run diagnostics:
  hermes doctor

EOF
}

if [ "${1:-}" != "--force" ] && [ -f "$SETUP_DONE_MARKER" ]; then
  echo "Hermes Agent is already configured. Skipping first-login setup."
  remove_first_login_hook
  exit 0
fi

if [ "${1:-}" != "--force" ] && [ -x /opt/hermes/apply-inference-from-env.sh ] && /opt/hermes/apply-inference-from-env.sh; then
  echo "Hermes Agent is already configured for DigitalOcean Serverless Inference. Skipping first-login setup."
  remove_first_login_hook
  exit 0
fi

if [ ! -f "$INFERENCE_MODELS_LIB" ]; then
  echo "ERROR: missing $INFERENCE_MODELS_LIB" >&2
  exit 1
fi

# shellcheck source=/var/lib/digitalocean/inference-models.sh
. "$INFERENCE_MODELS_LIB"

cat <<'EOF'

========================================================================
  Hermes Agent first-login setup
========================================================================

Hermes is installed for the dedicated 'hermes' user.
This wizard configures DigitalOcean Serverless Inference from a live
model catalog. Press Enter without a key to use Hermes built-in setup
instead (tools, terminal backend, and optional messaging gateway).

Create a model access key:
  1. Go to https://cloud.digitalocean.com/model-studio/manage-keys
  2. Or from the cloud console, navigate to Inference > Manage
  3. Click 'Create Model Access Key'

Docs: https://hermes-agent.nousresearch.com/docs/
GitHub: https://github.com/NousResearch/hermes-agent

EOF

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your DigitalOcean model access key (or press Enter for Hermes built-in setup): " MODEL_ACCESS_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "${MODEL_ACCESS_KEY}" ]; then
  echo ""
  echo "No model access key entered. Launching Hermes built-in setup..."
  echo ""
  run_builtin_hermes_setup
  finish_setup
  exit 0
fi

echo ""
echo "Fetching available models from DigitalOcean Serverless Inference..."

json=""
chat_ids=""
MODEL_ACCESS_MODEL=""
while true; do
  if json="$(fetch_inference_models_json "$MODEL_ACCESS_KEY")"; then
    chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
    if [ -z "$chat_ids" ]; then
      chat_ids="$(printf '%s' "$json" | parse_inference_model_ids)"
    fi
    if [ -n "$chat_ids" ]; then
      break
    fi
    echo "The inference API returned no models for this key."
  else
    status="${INFERENCE_MODELS_HTTP_STATUS:-000}"
    if [ "$status" = "401" ] || [ "$status" = "403" ]; then
      echo "That key was rejected (HTTP ${status})."
    else
      echo "Could not list models from https://inference.do-ai.run/v1/models (HTTP ${status})."
    fi
  fi

  echo ""
  echo "You can re-enter the key, type a model id to use this key anyway, or skip."
  old_histfile="${HISTFILE-}"
  unset HISTFILE
  read -rsp "Re-enter your model access key (or press Enter to keep the current key): " NEW_KEY
  echo ""
  [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"
  if [ -n "${NEW_KEY}" ]; then
    MODEL_ACCESS_KEY="$NEW_KEY"
    continue
  fi

  read -rp "Enter a DigitalOcean model id (or press Enter for Hermes built-in setup): " MODEL_ACCESS_MODEL
  if [ -n "${MODEL_ACCESS_MODEL}" ]; then
    chat_ids=""
    break
  fi

  echo ""
  echo "Launching Hermes built-in setup..."
  echo ""
  run_builtin_hermes_setup
  finish_setup
  exit 0
done

if [ -n "$chat_ids" ]; then
  default_model="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
  echo ""
  echo "Choose a default model (you can switch later with 'hermes model'):"
  echo ""
  i=1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf "  %2d) %s\n" "$i" "$line"
    i=$((i + 1))
  done <<<"$chat_ids"
  echo ""
  count=$((i - 1))
  read -rp "Selection [1-${count}, or Enter for ${default_model}]: " SEL
  if ! MODEL_ACCESS_MODEL="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "$SEL")"; then
    echo "Invalid selection; using ${default_model}."
    MODEL_ACCESS_MODEL="$default_model"
  fi
fi

export MODEL_ACCESS_KEY
export MODEL_ACCESS_MODEL
/opt/hermes/apply-inference-from-env.sh

echo ""
echo "Default model set to: ${MODEL_ACCESS_MODEL}"
echo "To configure Hermes tools, terminal backend, or a messaging gateway later:"
echo "  hermes setup"
finish_setup
