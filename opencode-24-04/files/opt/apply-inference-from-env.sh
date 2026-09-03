#!/bin/bash
# Apply DigitalOcean Serverless Inference from droplet env or /opt/opencode.env
# (MODEL_ACCESS_KEY, INFERENCE_MODEL, DO_INFERENCE_ROUTER).
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/opencode.env
CONFIG_FILE=/root/.config/opencode/opencode.json
AUTH_FILE=/root/.local/share/opencode/auth.json
SETUP_MARKER=/root/.opencode_setup_complete
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
DEFAULT_MODEL=minimax-m2.5
ROUTER_DISPLAY_NAME="DigitalOcean Intelligent Inference Router"

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

redact_inference_secrets_from_system_environment() {
    local env_file=/etc/environment
    [ -f "$env_file" ] || return 0
    grep -Ev '^MODEL_ACCESS_KEY=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
    mv "${env_file}.tmp" "$env_file"
    chmod 644 "$env_file"
}

write_auth_file() {
    mkdir -p /root/.config/opencode /root/.local/share/opencode
    jq -n --arg key "$MODEL_ACCESS_KEY" \
        '{
          "digitalocean": {"type": "api", "key": $key},
          "do-anthropic": {"type": "api", "key": $key}
        }' >"$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
}

# Replace digitalocean.models with the live catalog (plus an optional extra id).
sync_digitalocean_models() {
    local primary="$1"
    local extra_id="${2-}"
    local models_obj
    [ -f "$CONFIG_FILE" ] || return 0

    models_obj="$(printf '%s\n' "${CHAT_IDS:-}" | jq -R -s -c \
        --arg extra "$extra_id" \
        --arg dname "$ROUTER_DISPLAY_NAME" \
        --arg primary_id "${primary#digitalocean/}" '
      (split("\n") | map(select(length>0))) as $ids
      | (if ($primary_id != "" and ($ids | index($primary_id) | not))
         then [$primary_id] + $ids else $ids end) as $all
      | reduce $all[] as $id ({}; .[$id] = {"name": $id})
      | if $extra != "" then .[$extra] = {"name": $dname} else . end
    ')"

    jq --arg model "$primary" --argjson models "$models_obj" '
      .model = $model
      | .provider.digitalocean.models = $models
    ' "$CONFIG_FILE" >"${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

finish_apply() {
    local message="$1"
    redact_inference_secrets_from_system_environment
    touch "$SETUP_MARKER"
    remove_setup_bashrc_hook
    echo "$message"
    exit 0
}

MODEL_ACCESS_KEY=$(read_config_value MODEL_ACCESS_KEY || true)
INFERENCE_MODEL=$(read_config_value INFERENCE_MODEL || true)
DO_INFERENCE_ROUTER=$(read_config_value DO_INFERENCE_ROUTER || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
    exit 1
fi

CHAT_IDS=""
if [ -f "$INFERENCE_MODELS_LIB" ]; then
    # shellcheck source=/var/lib/digitalocean/inference-models.sh
    . "$INFERENCE_MODELS_LIB"
    CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY" || true)"
fi

write_env_file_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
write_auth_file

if env_value_usable "$DO_INFERENCE_ROUTER"; then
    ROUTER_NAME=$(normalize_router_name "$DO_INFERENCE_ROUTER")
    if [ -n "$ROUTER_NAME" ]; then
        if ! env_value_usable "$INFERENCE_MODEL"; then
            if [ -n "$CHAT_IDS" ]; then
                INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | pick_default_inference_model)"
            else
                INFERENCE_MODEL="$DEFAULT_MODEL"
            fi
        fi
        write_env_file_kv INFERENCE_MODEL "${INFERENCE_MODEL#digitalocean/}"
        write_env_file_kv DO_INFERENCE_ROUTER "$ROUTER_NAME"
        sync_digitalocean_models "digitalocean/router:${ROUTER_NAME}" "router:${ROUTER_NAME}"
        finish_apply "DigitalOcean Serverless Inference configured from droplet environment: router ${ROUTER_NAME} (digitalocean/router:${ROUTER_NAME})"
    fi
fi

if ! env_value_usable "$INFERENCE_MODEL"; then
    if [ -n "$CHAT_IDS" ]; then
        INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | pick_default_inference_model)"
    else
        INFERENCE_MODEL="$DEFAULT_MODEL"
    fi
fi

PRIMARY_MODEL=$(normalize_opencode_model "$INFERENCE_MODEL")
write_env_file_kv INFERENCE_MODEL "${PRIMARY_MODEL#digitalocean/}"
write_env_file_kv DO_INFERENCE_ROUTER ""

sync_digitalocean_models "$PRIMARY_MODEL"

finish_apply "DigitalOcean Serverless Inference configured from droplet environment: model ${PRIMARY_MODEL}"
