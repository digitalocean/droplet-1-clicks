#!/bin/bash

# OpenClaw Token Setup Script
# Run this script to configure OpenClaw with a AI API key

SETUP_DONE_MARKER=/home/openclaw/.openclaw/provider-configured

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

env_value_configured() {
  local key="$1" line val
  [ -f /opt/openclaw.env ] || return 1
  line=$(grep -E "^${key}=" /opt/openclaw.env 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
  case "$val" in
    ''|*'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
  esac
  return 0
}

codex_oauth_configured() {
  local state_dir auth_file
  state_dir=/home/openclaw/.openclaw

  for auth_file in \
    "${state_dir}"/agents/*/auth-profiles.json \
    "${state_dir}"/agents/*/auth.json \
    "${state_dir}"/credentials/oauth.json; do
    [ -s "$auth_file" ] || continue
    if grep -Eiq 'openai|codex|refresh[_-]?token|access[_-]?token' "$auth_file"; then
      return 0
    fi
  done

  return 1
}

json_api_provider_configured() {
  local config_file=/home/openclaw/.openclaw/openclaw.json
  [ -f "$config_file" ] || return 1

  jq -e '
    (.models.providers // {})
    | to_entries
    | map(.value.apiKey? // empty)
    | any(. != null and . != "" and . != "PLACEHOLDER" and (. | tostring | startswith("${") | not))
  ' "$config_file" >/dev/null 2>&1
}

model_setup_configured() {
  local config_file=/home/openclaw/.openclaw/openclaw.json
  [ -f "$config_file" ] || return 1

  jq -e '
    (.agents.defaults.model.primary // "") as $primary
    | ($primary != "" and $primary != "PLACEHOLDER" and ($primary | startswith("${") | not))
  ' "$config_file" >/dev/null 2>&1
}

configured_provider_reason() {
  local configured_key

  if [ -f "$SETUP_DONE_MARKER" ]; then
    echo "provider setup is already complete"
    return 0
  fi

  if [ -f /home/openclaw/.openclaw/openclaw.json ]; then
    configured_key=$(jq -r '.models.providers.digitalocean.apiKey // .models.providers.gradient.apiKey // empty' /home/openclaw/.openclaw/openclaw.json 2>/dev/null || true)
    if [ -n "$configured_key" ] && [ "$configured_key" != "PLACEHOLDER" ] && [ "$configured_key" != "null" ]; then
      echo "DigitalOcean Serverless Inference is already configured"
      return 0
    fi
  fi

  if json_api_provider_configured; then
    echo "an API-key provider is already configured"
    return 0
  fi

  if codex_oauth_configured; then
    echo "OpenAI Codex OAuth is already configured"
    return 0
  fi

  if env_value_configured OPENAI_API_KEY; then
    echo "OpenAI API key is already configured"
    return 0
  fi
  if env_value_configured ANTHROPIC_API_KEY; then
    echo "Anthropic API key is already configured"
    return 0
  fi
  if env_value_configured OPENROUTER_API_KEY; then
    echo "OpenRouter API key is already configured"
    return 0
  fi

  if model_setup_configured; then
    echo "OpenClaw model setup is already configured"
    return 0
  fi

  return 1
}

configured_reason=$(configured_provider_reason || true)
if [ -n "$configured_reason" ]; then
  echo "${configured_reason}. Skipping provider setup."
  if [ -x /opt/sync-openclaw-gateway.sh ]; then
    /opt/sync-openclaw-gateway.sh 2>/dev/null || true
  fi
  remove_first_login_hook
  echo "Control UI pairing: sudo /opt/openclaw-control-ui-pairing.sh"
  exit 0
fi

# OpenClaw first-login setup (DigitalOcean 1-Click)
# Configures models and gateway; see authoritative docs at the URLs printed below.

DOCS_MAIN="https://docs.clawd.bot/"
DOCS_OPENAI="https://github.com/openclaw/openclaw/blob/main/docs/providers/openai.md"
DOCS_REPO="https://github.com/openclaw/openclaw"

# Public IPv4 from DO metadata (matches browser URL). Private IP is often first in
# hostname -I — using only that caused gateway.controlUi.allowedOrigins mismatches
# ("origin not allowed") when users opened https://<public-ip>/.
droplet_public_ip() {
  curl -fsS --retry 5 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true
}

DROPL_PRIVATE_IP=$(hostname -I | awk '{print $1}')
DROPL_PUBLIC_IP=$(droplet_public_ip)
if [ -n "$DROPL_PUBLIC_IP" ]; then
  DROPL_IP="$DROPL_PUBLIC_IP"
  DASHBOARD_HOST="$DROPL_PUBLIC_IP"
else
  DROPL_IP="$DROPL_PRIVATE_IP"
  DASHBOARD_HOST="$DROPL_PRIVATE_IP"
fi

read_openclaw_gateway_token() {
  local line val
  if [ -f /opt/openclaw.env ]; then
    line=$(grep -E '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env 2>/dev/null | tail -n 1) || true
    if [ -n "$line" ]; then
val="${line#OPENCLAW_GATEWAY_TOKEN=}"; val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
      case "$val" in
        ''|*'${'*|PLACEHOLDER*) ;;
        *) printf '%s' "$val"; return 0 ;;
      esac
    fi
  fi
  if [ -f /home/openclaw/.openclaw/openclaw.json ]; then
    jq -r '.gateway.auth.token // .gateway.remote.token // empty' \
      /home/openclaw/.openclaw/openclaw.json 2>/dev/null | \
      grep -vE '^(null|PLACEHOLDER|\$\{)' || true
  fi
}

sync_openclaw_gateway_or_exit() {
  chmod +x /opt/sync-openclaw-gateway.sh
  if ! /opt/sync-openclaw-gateway.sh; then
    echo "ERROR: Could not sync OPENCLAW_GATEWAY_TOKEN into openclaw.json." >&2
    echo "Check /opt/openclaw.env and /home/openclaw/.openclaw/openclaw.json." >&2
    exit 1
  fi
}

ensure_gateway_reachable_for_onboard() {
  local i code

  sync_openclaw_gateway_or_exit
  systemctl restart openclaw || true

  printf "Waiting for local OpenClaw gateway before onboarding..."
  for i in $(seq 1 30); do
    code=$(curl -so /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:18789/ 2>/dev/null || true)
    if [ "$code" != "000" ] && [ -n "$code" ]; then
      printf " ready.\n"
      return 0
    fi
    sleep 2
    printf "."
  done

  printf "\n"
  echo "Warning: local gateway did not respond before onboarding." >&2
  echo "The built-in 'Hatch in web' option may be hidden; choose 'Hatch later' and use the 1-Click Control UI pairing after setup." >&2
  return 1
}

configure_digitalocean_inference() {
  local INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
  local json chat_ids default_model SEL NEW_KEY

  if [ ! -f "$INFERENCE_MODELS_LIB" ]; then
    echo "ERROR: missing $INFERENCE_MODELS_LIB" >&2
    exit 1
  fi
  # shellcheck source=/var/lib/digitalocean/inference-models.sh
  . "$INFERENCE_MODELS_LIB"

  cat <<'EOF'

Configure Your Model Access Key:
  https://cloud.digitalocean.com/model-studio/manage-keys
  (cloud console: Inference > Manage > Create Model Access Key)

EOF

  old_histfile="${HISTFILE-}"
  unset HISTFILE
  read -rsp "Enter your model access key: " MODEL_ACCESS_KEY
  echo ""
  [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

  while [ -z "${MODEL_ACCESS_KEY}" ]; do
    echo "A model access key is required for DigitalOcean Serverless Inference."
    old_histfile="${HISTFILE-}"
    unset HISTFILE
    read -rsp "Enter your model access key: " MODEL_ACCESS_KEY
    echo ""
    [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"
  done

  echo ""
  echo "Fetching available models from DigitalOcean Serverless Inference..."

  json=""
  chat_ids=""
  INFERENCE_MODEL=""
  while true; do
    if json="$(fetch_inference_models_json "$MODEL_ACCESS_KEY")"; then
      chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
      if [ -z "$chat_ids" ]; then
        chat_ids="$(printf '%s' "$json" | parse_inference_model_ids)"
      fi
      if [ -n "$chat_ids" ]; then
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
    echo "You can re-enter the key, or type a model id to use this key anyway."
    old_histfile="${HISTFILE-}"
    unset HISTFILE
    read -rsp "Re-enter your model access key (or press Enter to keep the current key): " NEW_KEY
    echo ""
    [ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"
    if [ -n "${NEW_KEY}" ]; then
      MODEL_ACCESS_KEY="$NEW_KEY"
      continue
    fi

    read -rp "Enter a DigitalOcean model id: " INFERENCE_MODEL
    if [ -n "${INFERENCE_MODEL}" ]; then
      chat_ids=""
      break
    fi
  done

  if [ -n "$chat_ids" ]; then
    default_model="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
    echo ""
    echo "Choose a default model:"
    echo ""
    i=1
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf "  %2d) %s\n" "$i" "$line"
      i=$((i + 1))
    done <<<"$chat_ids"
    echo ""
    count=$((i - 1))
    read -rp "Enter 1-${count} [default: 1]: " SEL
    if ! INFERENCE_MODEL="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "$SEL")"; then
      echo "Invalid selection; using ${default_model}."
      INFERENCE_MODEL="$default_model"
    fi
  fi

  export MODEL_ACCESS_KEY
  export INFERENCE_MODEL
  /opt/apply-inference-from-env.sh
  echo "Default model set to: ${INFERENCE_MODEL}"
}

PS3="Select a provider (1-6): "
options=(
  "DigitalOcean Serverless Inference"
  "OpenAI (API key — usage billing)"
  "OpenAI Codex (ChatGPT / subscription OAuth)"
  "Anthropic"
  "OpenRouter"
  "OpenClaw Model Setup"
)

echo ""
echo "========================================================================"
echo "  OpenClaw — authoritative documentation"
echo "========================================================================"
echo "  Project docs:     ${DOCS_MAIN}"
echo "  OpenAI & Codex:   ${DOCS_OPENAI}"
echo "  Source / issues:  ${DOCS_REPO}"
echo "========================================================================"
echo ""
echo "OpenAI has two different setups: an API key (platform billing) vs"
echo "ChatGPT/Codex subscription (OAuth). They are not interchangeable — see the"
echo "OpenAI provider doc above before changing config."
echo ""
echo "--- AI Provider Selector ---"

selected_provider="n/a"
target_config="n/a"

select opt in "${options[@]}"
do
  case $opt in
    "DigitalOcean Serverless Inference")
        selected_provider="DigitalOcean Serverless Inference"
        target_config="/etc/config/digitalocean-inference.json"
        echo "You selected DigitalOcean Serverless Inference."
        break
        ;;
    "OpenAI (API key — usage billing)")
        selected_provider="OpenAI"
        target_config="/etc/config/openai.json"
        env_key_name="OPENAI_API_KEY"
        echo "You selected OpenAI via API key (OPENAI_API_KEY)."
        echo "For ChatGPT / Codex subscription (OAuth), cancel (Ctrl+C) and choose"
        echo "'OpenAI Codex' instead, or see: ${DOCS_OPENAI}"
        break
        ;;
    "OpenAI Codex (ChatGPT / subscription OAuth)")
        selected_provider="OpenAI Codex"
        target_config=""
        echo "You selected OpenAI Codex (subscription OAuth via OpenClaw onboard)."
        echo "Follow the prompts. Official details: ${DOCS_OPENAI}"
        break
        ;;
    "Anthropic")
        selected_provider="Anthropic"
        target_config="/etc/config/anthropic.json"
        env_key_name="ANTHROPIC_API_KEY"
        echo "You selected Anthropic."
        break
        ;;
    "OpenRouter")
        selected_provider="OpenRouter"
        target_config="/etc/config/openrouter.json"
        env_key_name="OPENROUTER_API_KEY"
        echo "You selected OpenRouter."
        break
        ;;
    "OpenClaw Model Setup")
        selected_provider="OpenClaw Model Setup"
        target_config="/etc/config/openclaw.json"
        echo "You selected OpenClaw Built-in Model Setup."
        echo "When prompted 'Where will the Gateway run?' please select 'Local'"
        break
        ;;
    *)
        echo "Invalid option. Please try again."
        ;;
  esac
done

echo ""
echo "${selected_provider} Configuration Setup"
echo "=============================="
echo ""

mkdir -p /home/openclaw/.openclaw

if [[ "$selected_provider" == "OpenClaw Model Setup" ]]; then
  /opt/openclaw-cli.sh configure --section model
  jq -s '.[0] * .[1]' /home/openclaw/.openclaw/openclaw.json ${target_config} > /home/openclaw/.openclaw/openclaw.json.bak
  cp /home/openclaw/.openclaw/openclaw.json.bak /home/openclaw/.openclaw/openclaw.json
elif [[ "$selected_provider" == "OpenAI Codex" ]]; then
  if [ ! -f /home/openclaw/.openclaw/openclaw.json ]; then
    cp /etc/config/openclaw.json /home/openclaw/.openclaw/openclaw.json
    chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
  fi
  ensure_gateway_reachable_for_onboard || true
  echo "Starting OpenClaw onboarding for Codex (interactive; browser / device flow may be required)..."
  echo "Reference: ${DOCS_OPENAI}"
  echo "If the Hatch menu does not show 'Hatch in web', choose 'Hatch later'; this 1-Click runs Control UI pairing after onboarding."
  if /opt/openclaw-cli.sh onboard --auth-choice openai-codex; then
    :
  else
    echo ""
    echo "Note: 'onboard --auth-choice openai-codex' failed or is unavailable in this CLI version."
    echo "Running generic interactive onboard; choose OpenAI / Codex when prompted."
    echo "Docs: ${DOCS_MAIN}"
    /opt/openclaw-cli.sh onboard || true
  fi
  if [ ! -f /home/openclaw/.openclaw/openclaw.json ]; then
    echo "Seeding minimal gateway config (onboard did not create openclaw.json)."
    cp /etc/config/openclaw.json /home/openclaw/.openclaw/openclaw.json
    chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
  fi
  sync_openclaw_gateway_or_exit
elif [[ "$selected_provider" == "DigitalOcean Serverless Inference" ]]; then
  configure_digitalocean_inference
else
  while [ -z "${model_access_key:-}" ]
    do
      read -p "Enter ${selected_provider} model access key: " model_access_key
    done
  if [[ "$selected_provider" == "OpenRouter" ]]; then
      jq --arg key "$model_access_key" '.models.providers.openrouter.apiKey = $key' "$target_config" > /home/openclaw/.openclaw/openclaw.json
  else
      cp ${target_config} /home/openclaw/.openclaw/openclaw.json
      echo -e "\n${env_key_name}=${model_access_key}" >> /opt/openclaw.env
  fi
fi

sync_openclaw_gateway_or_exit

GATEWAY_TOKEN=$(read_openclaw_gateway_token)
if [ -z "$GATEWAY_TOKEN" ]; then
  echo "ERROR: Could not read OPENCLAW_GATEWAY_TOKEN from /opt/openclaw.env or openclaw.json." >&2
  exit 1
fi

echo "gateway.controlUi.allowedOrigins -> $(jq -c '.gateway.controlUi.allowedOrigins' /home/openclaw/.openclaw/openclaw.json)"
echo "gateway.auth.token / gateway.remote.token -> configured"
echo "(Open the Control UI at https://${DASHBOARD_HOST}/ so the browser Origin matches.)"

chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 0600 /home/openclaw/.openclaw/openclaw.json
printf '%s\n' "$selected_provider" > "$SETUP_DONE_MARKER"
chown openclaw:openclaw "$SETUP_DONE_MARKER"
chmod 0600 "$SETUP_DONE_MARKER"

echo ""
if [[ "$selected_provider" == "OpenAI Codex" ]]; then
  echo "OpenClaw Codex onboarding step finished. Run /opt/openclaw-cli.sh doctor if your CLI version supports it."
else
  echo "${selected_provider} key configured successfully."
fi
echo "Authoritative docs: ${DOCS_MAIN} | OpenAI/Codex: ${DOCS_OPENAI}"
echo "Restarting OpenClaw service..."
systemctl restart openclaw

sleep 2

if systemctl is-active --quiet openclaw; then
    echo "✅ OpenClaw restarted successfully!"
else
    echo "⚠️ Service may need attention. Check with: systemctl status openclaw"
fi

cp -r /usr/lib/node_modules/openclaw/skills /home/openclaw/.openclaw/workspace/ 2>/dev/null || true

remove_first_login_hook
chmod +x /opt/openclaw-control-ui-pairing.sh
exec /opt/openclaw-control-ui-pairing.sh