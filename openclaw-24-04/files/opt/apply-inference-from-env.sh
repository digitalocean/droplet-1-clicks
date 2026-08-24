#!/bin/bash
# Apply DigitalOcean Serverless Inference from /etc/environment or /opt/openclaw.env.
# Returns 0 when a key was applied; 1 when skipped (empty or unset placeholder).
set -euo pipefail

ENV_FILE=/opt/openclaw.env
INFERENCE_CONFIG=/etc/config/digitalocean-inference.json
OPENCLAW_JSON=/home/openclaw/.openclaw/openclaw.json
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh
PROVIDER_PREFIX=digitalocean

remove_setup_wizard_bashrc_hook() {
    [ -f /root/.bashrc ] || return 0
    sed -i \
        -e '/chmod +x \/etc\/setup_wizard\.sh/d' \
        -e '/\/etc\/setup_wizard\.sh/d' \
        /root/.bashrc
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
    val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
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

read_first_usable() {
    local key val
    for key in "$@"; do
        val=$(read_config_value "$key" || true)
        if env_value_usable "$val"; then
            printf '%s' "$val"
            return 0
        fi
    done
    return 1
}

write_env_file_kv() {
    local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
    touch "$ENV_FILE"
    grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
    printf '%s=%q\n' "$key" "$val" >>"$tmp"
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
}

normalize_inference_model() {
    local m="$1"
    case "$m" in
        "${PROVIDER_PREFIX}"/*) printf '%s' "$m" ;;
        gradient/*) printf '%s/%s' "$PROVIDER_PREFIX" "${m#gradient/}" ;;
        "") return 1 ;;
        *) printf '%s/%s' "$PROVIDER_PREFIX" "$m" ;;
    esac
}

# Canonical env vars:
#   MODEL_ACCESS_KEY  official model access key
#   INFERENCE_MODEL   default model id from GET /v1/models
# Aliases still accepted from droplet environment:
#   GRADIENT_KEY, MODEL_ACCESS_MODEL, DO_INFERENCE_MODEL, GRADIENT_MODEL
MODEL_ACCESS_KEY=$(read_first_usable MODEL_ACCESS_KEY GRADIENT_KEY || true)
INFERENCE_MODEL=$(read_first_usable INFERENCE_MODEL MODEL_ACCESS_MODEL DO_INFERENCE_MODEL GRADIENT_MODEL || true)

if ! env_value_usable "$MODEL_ACCESS_KEY"; then
    exit 1
fi

CHAT_IDS=""
if [ -f "$INFERENCE_MODELS_LIB" ]; then
    # shellcheck source=/var/lib/digitalocean/inference-models.sh
    . "$INFERENCE_MODELS_LIB"
    CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY" || true)"
fi

if ! env_value_usable "$INFERENCE_MODEL"; then
    if [ -z "$CHAT_IDS" ]; then
        echo "Could not list Serverless Inference models and no INFERENCE_MODEL was set." >&2
        exit 1
    fi
    INFERENCE_MODEL="$(printf '%s\n' "$CHAT_IDS" | pick_default_inference_model)"
fi

INFERENCE_MODEL="${INFERENCE_MODEL#${PROVIDER_PREFIX}/}"
INFERENCE_MODEL="${INFERENCE_MODEL#gradient/}"

if [ -n "$CHAT_IDS" ]; then
    if ! printf '%s\n' "$CHAT_IDS" | grep -Fxq "$INFERENCE_MODEL"; then
        CHAT_IDS="$(printf '%s\n%s\n' "$INFERENCE_MODEL" "$CHAT_IDS")"
    fi
else
    CHAT_IDS="$INFERENCE_MODEL"
fi

PRIMARY_MODEL=$(normalize_inference_model "$INFERENCE_MODEL")
MODELS_JSON="$(printf '%s\n' "$CHAT_IDS" | jq -R -s -c '
    split("\n") | map(select(length>0)) |
    map({
        id: .,
        name: .,
        reasoning: false,
        input: ["text"],
        compat: {supportsStore: false, maxTokensField: "max_tokens"},
        cost: {input: 0, output: 0, cacheRead: 0, cacheWrite: 0}
    })
')"
DEFAULTS_MODELS="$(printf '%s\n' "$CHAT_IDS" | jq -R -s -c --arg p "$PROVIDER_PREFIX" '
    split("\n") | map(select(length>0)) |
    map({key: ($p + "/" + .), value: {params: {}}}) |
    from_entries
')"

GATEWAY_TOKEN=$(read_first_usable OPENCLAW_GATEWAY_TOKEN || true)
if ! env_value_usable "$GATEWAY_TOKEN"; then
    echo "apply-inference-from-env: OPENCLAW_GATEWAY_TOKEN not ready in $ENV_FILE" >&2
    exit 1
fi

if [ ! -f "$INFERENCE_CONFIG" ]; then
    echo "apply-inference-from-env: missing $INFERENCE_CONFIG" >&2
    exit 1
fi

write_env_file_kv MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
write_env_file_kv INFERENCE_MODEL "$INFERENCE_MODEL"
tmp="${ENV_FILE}.tmp"
grep -v -E '^(MODEL_ACCESS_MODEL|GRADIENT_KEY|GRADIENT_MODEL|DO_INFERENCE_MODEL)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

mkdir -p /home/openclaw/.openclaw

jq --arg key "$MODEL_ACCESS_KEY" \
    --arg model "$PRIMARY_MODEL" \
    --arg token "$GATEWAY_TOKEN" \
    --argjson models "$MODELS_JSON" \
    --argjson defaults "$DEFAULTS_MODELS" \
    '.models.providers.digitalocean.apiKey = $key
     | .models.providers.digitalocean.models = $models
     | .agents.defaults.model.primary = $model
     | .agents.defaults.models = $defaults
     | .gateway.auth.token = $token
     | .gateway.remote.token = $token' \
    "$INFERENCE_CONFIG" >"$OPENCLAW_JSON"

chmod +x /opt/sync-openclaw-gateway.sh
/opt/sync-openclaw-gateway.sh

if [ -d /usr/lib/node_modules/openclaw/skills ]; then
    mkdir -p /home/openclaw/.openclaw/workspace
    cp -r /usr/lib/node_modules/openclaw/skills /home/openclaw/.openclaw/workspace/ 2>/dev/null || true
    chown -R openclaw:openclaw /home/openclaw/.openclaw/workspace/skills 2>/dev/null || true
fi

chown openclaw:openclaw "$OPENCLAW_JSON"
chmod 600 "$OPENCLAW_JSON"

remove_setup_wizard_bashrc_hook

echo "OpenClaw configured for DigitalOcean Serverless Inference: ${PRIMARY_MODEL}"
exit 0
