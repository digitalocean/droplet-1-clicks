#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/openclaw.env (GRADIENT_KEY, GRADIENT_MODEL).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/openclaw.env
GRADIENT_CONFIG=/etc/config/gradientai.json
OPENCLAW_JSON=/home/openclaw/.openclaw/openclaw.json

remove_setup_wizard_bashrc_hook() {
    [ -f /root/.bashrc ] || return 0
    sed -i \
        -e '/chmod +x \/etc\/setup_wizard\.sh/d' \
        -e '/\/etc\/setup_wizard\.sh/d' \
        /root/.bashrc
}

read_file_kv() {
    local key="$1"
    local line val
    line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
    eval "val=${line#${key}=}"
    printf '%s' "$val"
}

read_config_value() {
    local key="$1"
    local env_val="${!key-}"
    if env_value_usable "$env_val"; then
        printf '%s' "$env_val"
        return 0
    fi
    read_file_kv "$key"
}

write_env_file_kv() {
    local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
    touch "$ENV_FILE"
    grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
    printf '%s=%q\n' "$key" "$val" >>"$tmp"
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

normalize_gradient_model() {
    local m="$1"
    case "$m" in
        gradient/*) printf '%s' "$m" ;;
        "") printf '%s' "gradient/minimax-m2.5" ;;
        *) printf 'gradient/%s' "$m" ;;
    esac
}

env_value_usable() {
    local v="$1"
    [ -n "$v" ] || return 1
    case "$v" in
        *'${'*|PLACEHOLDER*) return 1 ;;
    esac
    return 0
}

GRADIENT_KEY=$(read_config_value GRADIENT_KEY || true)
GRADIENT_MODEL=$(read_config_value GRADIENT_MODEL || true)

if ! env_value_usable "$GRADIENT_KEY"; then
    exit 1
fi

if ! env_value_usable "$GRADIENT_MODEL"; then
    GRADIENT_MODEL="minimax-m2.5"
fi

PRIMARY_MODEL=$(normalize_gradient_model "$GRADIENT_MODEL")
write_env_file_kv GRADIENT_KEY "$GRADIENT_KEY"
write_env_file_kv GRADIENT_MODEL "${PRIMARY_MODEL#gradient/}"

DROPLET_IP="$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
if [ -z "$DROPLET_IP" ]; then
    DROPLET_IP="$(hostname -I | awk '{print $1}')"
fi

GATEWAY_TOKEN=$(grep "^OPENCLAW_GATEWAY_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)
if ! env_value_usable "$GATEWAY_TOKEN"; then
    echo "apply-gradient-from-env: OPENCLAW_GATEWAY_TOKEN not ready in $ENV_FILE" >&2
    exit 1
fi

mkdir -p /home/openclaw/.openclaw

jq --arg key "$GRADIENT_KEY" \
    --arg model "$PRIMARY_MODEL" \
    '.models.providers.gradient.apiKey = $key | .agents.defaults.model.primary = $model' \
    "$GRADIENT_CONFIG" >"$OPENCLAW_JSON"

jq --arg token "$GATEWAY_TOKEN" \
    '.gateway.auth.token = $token' \
    "$OPENCLAW_JSON" >"${OPENCLAW_JSON}.tmp"
mv "${OPENCLAW_JSON}.tmp" "$OPENCLAW_JSON"

if [ -n "$DROPLET_IP" ]; then
    jq --arg origin "https://${DROPLET_IP}" \
        '.gateway.controlUi.allowedOrigins = [ $origin ]' \
        "$OPENCLAW_JSON" >"${OPENCLAW_JSON}.tmp"
    mv "${OPENCLAW_JSON}.tmp" "$OPENCLAW_JSON"
fi

chown openclaw:openclaw "$OPENCLAW_JSON"
chmod 0600 "$OPENCLAW_JSON"

if [ -d /usr/lib/node_modules/openclaw/skills ]; then
    mkdir -p /home/openclaw/.openclaw/workspace
    cp -r /usr/lib/node_modules/openclaw/skills /home/openclaw/.openclaw/workspace/ 2>/dev/null || true
    chown -R openclaw:openclaw /home/openclaw/.openclaw/workspace/skills 2>/dev/null || true
fi

remove_setup_wizard_bashrc_hook

echo "Gradient configured from ${ENV_FILE}: model ${PRIMARY_MODEL}"
exit 0
