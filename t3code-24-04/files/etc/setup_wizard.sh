#!/bin/bash
# First-login wizard for DigitalOcean Serverless Inference.
# Other T3 providers stay installed; sign those in as the t3 user.
set -euo pipefail

ENV_FILE=/opt/t3code-inference.env
MARKER=/home/t3/.t3/inference-configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"

cat <<EOF

========================================================================
  T3 Code first-login setup
========================================================================

Web UI:  https://${myip}
Pairing: /root/.t3code-pairing.txt
         Refresh with: /opt/create-t3code-pairing.sh

Native providers are installed for user t3. Sign in as that user, for example:
  runuser -u t3 -- bash -lc 'claude auth login'
  runuser -u t3 -- bash -lc 'codex login'
  runuser -u t3 -- bash -lc 'agent login'
  runuser -u t3 -- bash -lc 'grok login'
  runuser -u t3 -- bash -lc 'opencode auth login'
  runuser -u t3 -- bash -lc 'muse login'
  runuser -u t3 -- bash -lc 'fx login'
  runuser -u t3 -- bash -lc 'pi'

Antigravity signs in from Settings, then Providers, in the web UI.

EOF

if [ -f "$MARKER" ] && [ "${1:-}" != "--force" ]; then
  echo "DigitalOcean Serverless Inference is already configured."
  echo "Re-run with --force to replace it: /etc/setup_wizard.sh --force"
  remove_first_login_hook
  exit 0
fi

if [ "${1:-}" != "--force" ] && [ -x /opt/apply-inference-from-env.sh ] && /opt/apply-inference-from-env.sh; then
  echo "DigitalOcean Serverless Inference configured from the droplet environment."
  remove_first_login_hook
  exit 0
fi

cat <<'EOF'

------------------------------------------------------------------------
  Optional: DigitalOcean Serverless Inference
------------------------------------------------------------------------

This connects DigitalOcean Serverless Inference at https://inference.do-ai.run
using your model access key. In T3 Code, use the DigitalOcean Inference provider.

Create a key at: https://cloud.digitalocean.com/model-studio/manage-keys

Press Enter to skip and use another provider login instead.

EOF

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter your DigitalOcean model access key (or press Enter to skip): " MODEL_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$MODEL_KEY" ]; then
  echo "Skipped Serverless Inference. Sign in to a provider as user t3, or re-run /etc/setup_wizard.sh"
  remove_first_login_hook
  exit 0
fi

echo ""
echo "Testing the model access key..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${MODEL_KEY}" \
  -H "Content-Type: application/json" \
  https://inference.do-ai.run/v1/models 2>/dev/null || echo "000")

CHAT_IDS=""
if [ "$HTTP_STATUS" = "200" ] && [ -f "$INFERENCE_MODELS_LIB" ]; then
  echo "Connection successful."
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"
  CHAT_IDS="$(list_chat_inference_models "$MODEL_KEY" || true)"
else
  echo "Warning: inference API returned HTTP ${HTTP_STATUS}. Saving the key anyway."
fi

echo ""
echo "Choose a default model."
echo "  Press Enter for the default model,"
echo "  enter a list number or a model id, or R for an Intelligent Inference Router."
MODEL_COUNT=0
if [ -n "$CHAT_IDS" ]; then
  echo ""
  echo "Chat models on this key:"
  i=1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '  %2d) %s\n' "$i" "$line"
    i=$((i + 1))
  done <<<"$CHAT_IDS"
  MODEL_COUNT=$((i - 1))
fi

ROUTER_NAME=""
MODEL_ID=""
while true; do
  if [ "$MODEL_COUNT" -gt 0 ]; then
    read -r -p "Model [1-${MODEL_COUNT} / id / R, Enter for default]: " MODEL_SEL
  else
    read -r -p "Model id [Enter / id / R]: " MODEL_SEL
  fi

  if [ "$MODEL_SEL" = "R" ] || [ "$MODEL_SEL" = "r" ]; then
    read -r -p "Router name: " ROUTER_NAME
    ROUTER_NAME="${ROUTER_NAME#openai/}"
    ROUTER_NAME="${ROUTER_NAME#digitalocean/}"
    ROUTER_NAME="${ROUTER_NAME#router:}"
    if [ -z "$ROUTER_NAME" ]; then
      echo "Enter a router name, or choose a model instead."
      continue
    fi
    break
  fi

  if [ -z "$MODEL_SEL" ]; then
    break
  fi

  if [ -n "$CHAT_IDS" ]; then
    if MODEL_ID="$(printf '%s\n' "$CHAT_IDS" | resolve_inference_model_choice "$MODEL_SEL")"; then
      echo "Selected model: ${MODEL_ID}"
      break
    fi
    echo "Enter a number from 1 to ${MODEL_COUNT}, or a model id from the list."
    continue
  fi

  MODEL_ID="$MODEL_SEL"
  break
done

tmp="${ENV_FILE}.tmp"
touch "$ENV_FILE"
grep -v -E '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
printf 'MODEL_ACCESS_KEY=%s\n' "$MODEL_KEY" >>"$tmp"
if [ -n "$MODEL_ID" ]; then
  printf 'INFERENCE_MODEL=%s\n' "$MODEL_ID" >>"$tmp"
fi
printf 'DO_INFERENCE_ROUTER=%s\n' "$ROUTER_NAME" >>"$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

export MODEL_ACCESS_KEY="$MODEL_KEY"
if [ -n "$MODEL_ID" ]; then
  export INFERENCE_MODEL="$MODEL_ID"
else
  unset INFERENCE_MODEL || true
fi
export DO_INFERENCE_ROUTER="$ROUTER_NAME"

/opt/apply-inference-from-env.sh
remove_first_login_hook

cat <<EOF

========================================================================
  Inference setup complete.

  Open:   https://${myip}
  Pair:   /root/.t3code-pairing.txt
  Model:  see INFERENCE_MODEL in /opt/t3code-inference.env

  In T3 Code, select the DigitalOcean Inference provider and its custom model.
  Workspace: /home/t3/workspace
========================================================================

EOF
