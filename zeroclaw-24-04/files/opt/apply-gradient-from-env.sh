#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/zeroclaw.env (GRADIENT_KEY, GRADIENT_MODEL).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/zeroclaw.env
SETUP_MARKER=/root/.zeroclaw_setup_complete
DEFAULT_MODEL=kimi-k2.5
GRADIENT_PROVIDER=custom:https://inference.do-ai.run/v1
ALLOWED_MODELS="kimi-k2.5 minimax-m2.5 glm-5 anthropic-claude-4.5-sonnet"

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
    umask 077
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

gradient_model_allowed() {
    local m="$1" allowed
    for allowed in $ALLOWED_MODELS; do
        [ "$m" = "$allowed" ] && return 0
    done
    return 1
}

normalize_gradient_model() {
    local m="$1"
    m="${m#gradient/}"
    case "$m" in
        '') m="$DEFAULT_MODEL" ;;
    esac
    if ! gradient_model_allowed "$m"; then
        echo "Warning: Unknown GRADIENT_MODEL '${m}'; using ${DEFAULT_MODEL}." >&2
        m="$DEFAULT_MODEL"
    fi
    printf '%s' "$m"
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

/opt/zeroclaw-run-onboard.sh "$GRADIENT_KEY" "$GRADIENT_PROVIDER" "$PRIMARY_MODEL"

systemctl enable zeroclaw
systemctl restart zeroclaw

remove_setup_wizard_bashrc_hook
redact_gradient_secrets_from_system_environment
umask 077
touch "$SETUP_MARKER"
chmod 600 "$SETUP_MARKER"

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
