#!/bin/bash
# Apply DigitalOcean Serverless Inference from /etc/environment or /opt/hermes/hermes.env.
# Returns 0 when configured, 1 when skipped because no usable key is present.
set -euo pipefail

ENV_FILE=/opt/hermes/hermes.env
HERMES_HOME=/home/hermes/.hermes
HERMES_ENV="${HERMES_HOME}/.env"
HERMES_CONFIG="${HERMES_HOME}/config.yaml"
SETUP_DONE_MARKER="${HERMES_HOME}/provider-configured"
INFERENCE_MODELS_LIB=/var/lib/digitalocean/inference-models.sh

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
    local file="$1" key="$2" val="$3" tmp
    tmp="${file}.tmp"
    touch "$file"
    grep -v "^${key}=" "$file" >"$tmp" 2>/dev/null || : >"$tmp"
    printf '%s=%q\n' "$key" "$val" >>"$tmp"
    mv "$tmp" "$file"
    chmod 600 "$file"
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

if [ -n "$CHAT_IDS" ]; then
    MODELS_JSON="$(printf '%s\n' "$CHAT_IDS" | jq -R -s -c 'split("\n") | map(select(length>0))')"
    if ! printf '%s\n' "$CHAT_IDS" | grep -Fxq "$INFERENCE_MODEL"; then
        MODELS_JSON="$(jq -c --arg m "$INFERENCE_MODEL" '[$m] + .' <<<"$MODELS_JSON")"
    fi
else
    MODELS_JSON="$(jq -nc --arg m "$INFERENCE_MODEL" '[$m]')"
fi

mkdir -p "$HERMES_HOME"
chown hermes:hermes "$HERMES_HOME"
chmod 700 "$HERMES_HOME"

write_env_file_kv "$ENV_FILE" MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"
write_env_file_kv "$ENV_FILE" INFERENCE_MODEL "$INFERENCE_MODEL"
write_env_file_kv "$HERMES_ENV" MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY"

# Keep /opt/hermes/hermes.env on the canonical names.
tmp="${ENV_FILE}.tmp"
grep -v -E '^(MODEL_ACCESS_MODEL|GRADIENT_KEY|GRADIENT_MODEL|DO_INFERENCE_MODEL)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"

HERMES_MODELS_JSON="$MODELS_JSON" python3 - "$HERMES_CONFIG" "$INFERENCE_MODEL" <<'PY'
import json
import os
import sys

path, model = sys.argv[1], sys.argv[2]
models = json.loads(os.environ.get("HERMES_MODELS_JSON") or "[]")
if model not in models:
    models = [model] + models
config = {
    "model": {
        "provider": "custom",
        "default": model,
        "base_url": "https://inference.do-ai.run/v1",
        "api_key": "${MODEL_ACCESS_KEY}",
    },
    "custom_providers": [
        {
            "name": "digitalocean-inference",
            "base_url": "https://inference.do-ai.run/v1",
            "key_env": "MODEL_ACCESS_KEY",
            "api_mode": "chat_completions",
            "models": models,
        }
    ],
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY

printf '%s\n' "DigitalOcean Serverless Inference" > "$SETUP_DONE_MARKER"
chown -R hermes:hermes "$HERMES_HOME"
chmod 600 "$HERMES_ENV" "$HERMES_CONFIG" "$SETUP_DONE_MARKER"

echo "Hermes configured for DigitalOcean Serverless Inference: ${INFERENCE_MODEL}"
exit 0
