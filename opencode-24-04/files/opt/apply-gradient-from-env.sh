#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/opencode.env (GRADIENT_KEY, GRADIENT_MODEL).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/opencode.env
CONFIG_FILE=/root/.config/opencode/opencode.json
AUTH_FILE=/root/.local/share/opencode/auth.json
SETUP_MARKER=/root/.opencode_setup_complete

remove_setup_bashrc_hook() {
    [ -f /root/.bashrc ] || return 0
    sed -i '/\/opt\/setup-opencode\.sh/d' /root/.bashrc
}

read_file_kv() {
    local key="$1"
    local line val
    line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
    val="${line#${key}=}"
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

normalize_opencode_model() {
    local m="$1"
    case "$m" in
        digitalocean/*) printf '%s' "$m" ;;
        gradient/*) printf 'digitalocean/%s' "${m#gradient/}" ;;
        "") printf '%s' "digitalocean/minimax-m2.5" ;;
        *) printf 'digitalocean/%s' "$m" ;;
    esac
}

env_value_usable() {
    local v="$1"
    [ -n "$v" ] || return 1
    case "$v" in
        *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
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

PRIMARY_MODEL=$(normalize_opencode_model "$GRADIENT_MODEL")
write_env_file_kv GRADIENT_KEY "$GRADIENT_KEY"
write_env_file_kv GRADIENT_MODEL "${PRIMARY_MODEL#digitalocean/}"

mkdir -p /root/.config/opencode /root/.local/share/opencode

jq -n --arg key "$GRADIENT_KEY" \
    '{
      "digitalocean": {"type": "api", "key": $key},
      "do-anthropic": {"type": "api", "key": $key}
    }' >"$AUTH_FILE"
chmod 600 "$AUTH_FILE"

if [ -f "$CONFIG_FILE" ]; then
    jq --arg model "$PRIMARY_MODEL" '.model = $model' "$CONFIG_FILE" >"${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

touch "$SETUP_MARKER"
remove_setup_bashrc_hook

echo "Gradient configured from droplet environment: model ${PRIMARY_MODEL}"
exit 0
