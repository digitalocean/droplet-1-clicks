#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/zeroclaw.env (GRADIENT_KEY, GRADIENT_MODEL).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/zeroclaw.env
CONFIG_FILE=/home/zeroclaw/.zeroclaw/config.toml
SETUP_MARKER=/home/zeroclaw/.zeroclaw/gradient-configured
DEFAULT_MODEL=kimi-k2.5
GRADIENT_PROVIDER=custom:https://inference.do-ai.run/v1

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
    val="${line#${key}=}"
    val="${val#\"}"; val="${val%\"}"
    val="${val#\'}"; val="${val%\'}"
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

env_value_usable() {
    local v="$1"
    [ -n "$v" ] || return 1
    case "$v" in
        *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
    esac
    return 0
}

normalize_gradient_model() {
    local m="$1"
    m="${m#gradient/}"
    case "$m" in
        '') printf '%s' "$DEFAULT_MODEL" ;;
        *) printf '%s' "$m" ;;
    esac
}

redact_gradient_secrets_from_system_environment() {
    local env_file=/etc/environment
    [ -f "$env_file" ] || return 0
    grep -Ev '^(GRADIENT_KEY|GRADIENT_MODEL)=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
    mv "${env_file}.tmp" "$env_file"
    chmod 644 "$env_file"
}

GRADIENT_KEY=$(read_config_value GRADIENT_KEY || true)
GRADIENT_MODEL=$(read_config_value GRADIENT_MODEL || true)

if ! env_value_usable "$GRADIENT_KEY"; then
    exit 1
fi

if ! env_value_usable "$GRADIENT_MODEL"; then
    GRADIENT_MODEL="$DEFAULT_MODEL"
fi

PRIMARY_MODEL=$(normalize_gradient_model "$GRADIENT_MODEL")
write_env_file_kv GRADIENT_KEY "$GRADIENT_KEY"
write_env_file_kv GRADIENT_MODEL "$PRIMARY_MODEL"

mkdir -p /home/zeroclaw/.zeroclaw
chown zeroclaw:zeroclaw /home/zeroclaw/.zeroclaw

su - zeroclaw -c "/usr/local/bin/zeroclaw onboard --force \
  --api-key '${GRADIENT_KEY}' \
  --provider '${GRADIENT_PROVIDER}' \
  --model '${PRIMARY_MODEL}'" > /dev/null 2>&1

if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/^port = .*/port = 42617/' "$CONFIG_FILE"
    chown zeroclaw:zeroclaw "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
fi

systemctl enable zeroclaw
systemctl restart zeroclaw

remove_setup_wizard_bashrc_hook
redact_gradient_secrets_from_system_environment
touch "$SETUP_MARKER"
chown zeroclaw:zeroclaw "$SETUP_MARKER" 2>/dev/null || true

echo "Testing connection to DigitalOcean Gradient..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${GRADIENT_KEY}" \
    -H "Content-Type: application/json" \
    https://inference.do-ai.run/v1/models 2>/dev/null || true)

if [ "$HTTP_STATUS" = "200" ]; then
    echo "Gradient configured from ${ENV_FILE}: model ${PRIMARY_MODEL}"
else
    echo "Gradient configured from ${ENV_FILE}: model ${PRIMARY_MODEL}"
    echo "Warning: Received HTTP ${HTTP_STATUS:-000} from the Gradient API." >&2
fi

exit 0
