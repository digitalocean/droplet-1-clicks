#!/bin/bash
set -euo pipefail

SETUP_MARKER=/root/.nod_inference_configured
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
OPT_ENV_FILE=/opt/nod.env

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

if [ "${1:-}" != "--force" ] && [ -f "$SETUP_MARKER" ]; then
  echo "Nod Serverless Inference is already configured. Skipping first-login setup."
  remove_first_login_hook
  exit 0
fi

if [ "${1:-}" != "--force" ] && [ -x /opt/apply-inference-from-env.sh ] && /opt/apply-inference-from-env.sh; then
  echo "Nod is already configured for DigitalOcean Serverless Inference. Skipping first-login setup."
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
  Nod first-login setup — DigitalOcean Serverless Inference
========================================================================

Connect a DigitalOcean model access key so Nod can use Serverless Inference
(OpenAI-compatible endpoint https://inference.do-ai.run/v1).

Create a key:
  https://cloud.digitalocean.com/gen-ai/model-access-keys

You can skip and connect a provider later in the Nod web UI (Models).

EOF

read -rp "Configure DigitalOcean Serverless Inference now? [Y/n]: " DO_SETUP
case "${DO_SETUP}" in
  n|N|no|NO)
    echo "Skipping. Open https://$(curl -fsS --max-time 2 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || hostname -I | awk '{print $1}') and connect a model in onboarding."
    remove_first_login_hook
    exit 0
    ;;
esac

read -rsp "Enter your model access key: " MODEL_ACCESS_KEY
echo
# Strip CR from pasted keys (Windows clipboard / terminal paste).
MODEL_ACCESS_KEY=$(printf '%s' "$MODEL_ACCESS_KEY" | tr -d '\r')
while [ -z "${MODEL_ACCESS_KEY}" ]; do
  echo "Key cannot be empty."
  read -rsp "Enter your model access key: " MODEL_ACCESS_KEY
  echo
  MODEL_ACCESS_KEY=$(printf '%s' "$MODEL_ACCESS_KEY" | tr -d '\r')
done

CHAT_IDS=""
if json="$(fetch_inference_models_json "$MODEL_ACCESS_KEY")"; then
  CHAT_IDS="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
  if [ -z "$CHAT_IDS" ]; then
    CHAT_IDS="$(printf '%s' "$json" | parse_inference_model_ids)"
  fi
else
  echo "Could not list models from https://inference.do-ai.run/v1/models for this key."
  echo "Check the key and try again: sudo /etc/setup_wizard.sh --force"
  exit 1
fi

if [ -z "$CHAT_IDS" ]; then
  echo "No models returned for this key."
  exit 1
fi

echo
echo "Available chat models:"
i=1
DEFAULT_MODEL="$(printf '%s\n' "$CHAT_IDS" | pick_default_inference_model)"
while IFS= read -r mid; do
  [ -n "$mid" ] || continue
  marker=""
  [ "$mid" = "$DEFAULT_MODEL" ] && marker=" (default)"
  printf '  %2d) %s%s\n' "$i" "$mid" "$marker"
  i=$((i + 1))
done <<EOF
$CHAT_IDS
EOF

echo
read -rp "Enter model number or id [default: ${DEFAULT_MODEL}]: " SEL
if [ -z "${SEL}" ]; then
  INFERENCE_MODEL="$DEFAULT_MODEL"
elif printf '%s' "$SEL" | grep -Eq '^[0-9]+$'; then
  INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | sed -n "${SEL}p")"
  if [ -z "$INFERENCE_MODEL" ]; then
    echo "Invalid selection."
    exit 1
  fi
else
  if ! INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | resolve_inference_model_choice "$SEL")"; then
    echo "Unknown model: $SEL"
    exit 1
  fi
fi

export MODEL_ACCESS_KEY
export INFERENCE_MODEL
# Clear router unless the user typed one.
unset DO_INFERENCE_ROUTER || true

# Persist into /opt/nod.env for re-apply.
touch "$OPT_ENV_FILE"
grep -vE '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$OPT_ENV_FILE" >"${OPT_ENV_FILE}.tmp" 2>/dev/null || : >"${OPT_ENV_FILE}.tmp"
printf 'MODEL_ACCESS_KEY=%s\n' "$MODEL_ACCESS_KEY" >>"${OPT_ENV_FILE}.tmp"
printf 'INFERENCE_MODEL=%s\n' "$INFERENCE_MODEL" >>"${OPT_ENV_FILE}.tmp"
printf 'DO_INFERENCE_ROUTER=\n' >>"${OPT_ENV_FILE}.tmp"
mv "${OPT_ENV_FILE}.tmp" "$OPT_ENV_FILE"
chmod 600 "$OPT_ENV_FILE"

/opt/apply-inference-from-env.sh
remove_first_login_hook

cat <<EOF

Nod is configured for DigitalOcean Serverless Inference.
  Model: ${INFERENCE_MODEL}
  Endpoint: https://inference.do-ai.run/v1

Open the Nod URL from the MOTD, paste NOD_AUTH_TOKEN, and continue.
Re-run anytime: sudo /etc/setup_wizard.sh --force

EOF
