#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/codex-cli.env (GRADIENT_KEY, GRADIENT_MODEL).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/codex-cli.env
CODEX_ENV=/root/.codex/env
CODEX_PROFILED=/etc/profile.d/codex-gradient.sh
CODEX_CONFIG=/root/.codex/config.toml
SETUP_MARKER=/root/.codex_setup_complete
DEFAULT_MODEL=openai-gpt-5.5
BASHRC_BEGIN='# codex-cli-24-04-gradient-env BEGIN'
BASHRC_END='# codex-cli-24-04-gradient-env END'
BASHRC_RANGE_BEGIN='codex-cli-24-04-gradient-env BEGIN'
BASHRC_RANGE_END='codex-cli-24-04-gradient-env END'

remove_setup_wizard_bashrc_hook() {
    [ -f /root/.bashrc ] || return 0
    sed -i '/\/opt\/setup-codex-cli\.sh/d' /root/.bashrc
}

ensure_codex_env_sourced() {
    touch /root/.bashrc
    if ! grep -qF "$BASHRC_RANGE_BEGIN" /root/.bashrc 2>/dev/null; then
        {
            echo ""
            echo "$BASHRC_BEGIN"
            echo "[ -f $CODEX_PROFILED ] && . $CODEX_PROFILED"
            echo "$BASHRC_END"
        } >> /root/.bashrc
    fi
}

write_codex_profiled() {
    local key="$1"
    umask 077
    mkdir -p /etc/profile.d
    printf 'export MODEL_ACCESS_KEY=%q\n' "$key" > "$CODEX_PROFILED"
    chmod 600 "$CODEX_PROFILED"
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
    case "$m" in
        '') printf '%s' "$DEFAULT_MODEL" ;;
        *) printf '%s' "$m" ;;
    esac
}

write_codex_env() {
    local key="$1"
    umask 077
    printf 'export MODEL_ACCESS_KEY=%q\n' "$key" > "$CODEX_ENV"
    chmod 600 "$CODEX_ENV"
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

mkdir -p /root/.codex
write_codex_profiled "$GRADIENT_KEY"
write_codex_env "$GRADIENT_KEY"
# shellcheck source=/dev/null
. "$CODEX_PROFILED"

if [ -f "$CODEX_CONFIG" ]; then
    if grep -q '^model = ' "$CODEX_CONFIG"; then
        sed -i "s|^model = .*|model = \"${PRIMARY_MODEL}\"|" "$CODEX_CONFIG"
    else
        echo "model = \"${PRIMARY_MODEL}\"" >> "$CODEX_CONFIG"
    fi
    chmod 600 "$CODEX_CONFIG"
fi

ensure_codex_env_sourced
remove_setup_wizard_bashrc_hook
redact_gradient_secrets_from_system_environment
touch "$SETUP_MARKER"

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
