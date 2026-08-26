#!/bin/bash
# Apply DigitalOcean Serverless Inference from droplet env or /opt/opencode.env.
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/opencode.env
CONFIG_FILE=/root/.config/opencode/opencode.json
AUTH_FILE=/root/.local/share/opencode/auth.json
SETUP_MARKER=/root/.opencode_setup_complete
DEFAULT_MODEL=minimax-m2.5

remove_setup_bashrc_hook() {
    [ -f /root/.bashrc ] || return 0
    sed -i '/\/opt\/setup-opencode\.sh/d' /root/.bashrc
}

env_value_usable() {
    local v="$1"
    [ -n "$v" ] || return 1
    case "$v" in
        *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
    esac
    return 0
}

read_file_kv() {
    local file="$1" key="$2" line val
    [ -f "$file" ] || return 1
    line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1) || return 1
    val="${line#${key}=}"
    val="${val#\"}"; val="${val%\"}"
    val="${val#\'}"; val="${val%\'}"
    printf '%s' "$val"
}

read_config_value() {
    local key="$1" val
    val="${!key-}"
    if env_value_usable "$val"; then
        printf '%s' "$val"
        return 0
    fi
    val=$(read_file_kv /etc/environment "$key" || true)
    if env_value_usable "$val"; then
        printf '%s' "$val"
        return 0
    fi
    read_file_kv "$ENV_FILE" "$key"
}

write_env_file_kv() {
    local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
    touch "$ENV_FILE"
    grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
    printf '%s=%q\n' "$key" "$val" >>"$tmp"
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

normalize_opencode_model() {
    local m="$1"
    case "$m" in
        digitalocean/*) printf '%s' "$m" ;;
        "") printf 'digitalocean/%s' "$DEFAULT_MODEL" ;;
        *) printf 'digitalocean/%s' "$m" ;;
    esac
}

redact_inference_secrets_from_system_environment() {
    local env_file=/etc/environment
    [ -f "$env_file" ] || return 0
    grep -Ev '^MODEL_ACCESS_KEY=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
    mv "${env_file}.tmp" "$env_file"
    chmod 644 "$env_file"
}

MODEL_ACCESS_KEY=$(read_config_value MODEL_ACCESS_KEY || true)
INFERENCE_MODEL=$(read_config_value INFERENCE_MODEL || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
    exit 1
fi

if ! env_value_usable "$INFERENCE_MODEL"; then
    INFERENCE_MODEL="$DEFAULT_MODEL"
fi

INFERENCE_MODEL="${INFERENCE_MODEL#digitalocean/}"

PRIMARY_MODEL=$(normalize_opencode_model "$INFERENCE_MODEL")
write_env_file_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
write_env_file_kv INFERENCE_MODEL "$INFERENCE_MODEL"

mkdir -p /root/.config/opencode /root/.local/share/opencode

jq -n --arg key "$MODEL_ACCESS_KEY" \
    '{
      "digitalocean": {"type": "api", "key": $key},
      "do-anthropic": {"type": "api", "key": $key}
    }' >"$AUTH_FILE"
chmod 600 "$AUTH_FILE"

if [ -f "$CONFIG_FILE" ]; then
    jq --arg model "$PRIMARY_MODEL" '.model = $model' "$CONFIG_FILE" >"${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

redact_inference_secrets_from_system_environment
touch "$SETUP_MARKER"
remove_setup_bashrc_hook

echo "DigitalOcean Serverless Inference configured from droplet environment: model ${PRIMARY_MODEL}"
exit 0
