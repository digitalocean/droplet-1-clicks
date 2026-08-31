#!/bin/bash
# Apply DigitalOcean Gradient from droplet env or /opt/opencode.env
# (GRADIENT_KEY, GRADIENT_MODEL, DO_INFERENCE_ROUTER).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/opencode.env
CONFIG_FILE=/root/.config/opencode/opencode.json
AUTH_FILE=/root/.local/share/opencode/auth.json
SETUP_MARKER=/root/.opencode_setup_complete
DEFAULT_MODEL=minimax-m2.5
ROUTER_DISPLAY_NAME="DigitalOcean Intelligent Inference Router"

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
        "") printf '%s' "digitalocean/${DEFAULT_MODEL}" ;;
        *) printf 'digitalocean/%s' "$m" ;;
    esac
}

# Accept "my-router", "router:my-router", or "digitalocean/router:my-router".
normalize_router_name() {
    local n="$1"
    n="${n#digitalocean/}"
    n="${n#router:}"
    printf '%s' "$n"
}

env_value_usable() {
    local v="$1"
    [ -n "$v" ] || return 1
    case "$v" in
        *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
    esac
    return 0
}

write_auth_file() {
    mkdir -p /root/.config/opencode /root/.local/share/opencode
    jq -n --arg key "$GRADIENT_KEY" \
        '{
          "digitalocean": {"type": "api", "key": $key},
          "do-anthropic": {"type": "api", "key": $key}
        }' >"$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
}

# Point the digitalocean router model at router:<name> and make it the default.
set_router_model() {
    local name="$1"
    local rid="router:${name}"
    local primary="digitalocean/${rid}"
    [ -f "$CONFIG_FILE" ] || return 0
    jq --arg model "$primary" --arg rid "$rid" --arg dname "$ROUTER_DISPLAY_NAME" '
      .model = $model
      | .provider.digitalocean.models |= with_entries(select(.key | startswith("router:") | not))
      | .provider.digitalocean.models[$rid] = {"name": $dname}
    ' "$CONFIG_FILE" >"${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

set_default_model() {
    local primary="$1"
    [ -f "$CONFIG_FILE" ] || return 0
    jq --arg model "$primary" '.model = $model' "$CONFIG_FILE" >"${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

GRADIENT_KEY=$(read_config_value GRADIENT_KEY || true)
GRADIENT_MODEL=$(read_config_value GRADIENT_MODEL || true)
DO_INFERENCE_ROUTER=$(read_config_value DO_INFERENCE_ROUTER || true)

if ! env_value_usable "$GRADIENT_KEY"; then
    exit 1
fi

write_env_file_kv GRADIENT_KEY "$GRADIENT_KEY"
write_auth_file

if env_value_usable "$DO_INFERENCE_ROUTER"; then
    ROUTER_NAME=$(normalize_router_name "$DO_INFERENCE_ROUTER")
    if [ -n "$ROUTER_NAME" ]; then
        if ! env_value_usable "$GRADIENT_MODEL"; then
            GRADIENT_MODEL="$DEFAULT_MODEL"
        fi
        write_env_file_kv GRADIENT_MODEL "${GRADIENT_MODEL#digitalocean/}"
        write_env_file_kv DO_INFERENCE_ROUTER "$ROUTER_NAME"
        set_router_model "$ROUTER_NAME"
        touch "$SETUP_MARKER"
        remove_setup_bashrc_hook
        echo "Gradient configured from droplet environment: router ${ROUTER_NAME} (digitalocean/router:${ROUTER_NAME})"
        exit 0
    fi
fi

if ! env_value_usable "$GRADIENT_MODEL"; then
    GRADIENT_MODEL="$DEFAULT_MODEL"
fi

PRIMARY_MODEL=$(normalize_opencode_model "$GRADIENT_MODEL")
write_env_file_kv GRADIENT_MODEL "${PRIMARY_MODEL#digitalocean/}"
write_env_file_kv DO_INFERENCE_ROUTER ""

set_default_model "$PRIMARY_MODEL"

touch "$SETUP_MARKER"
remove_setup_bashrc_hook

echo "Gradient configured from droplet environment: model ${PRIMARY_MODEL}"
exit 0
