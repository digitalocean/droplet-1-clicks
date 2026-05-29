#!/bin/bash
# Apply DigitalOcean Gradient from /etc/environment or /opt/hermes/hermes.env.
# Returns 0 when configured, 1 when skipped because no usable key is present.
set -euo pipefail

ENV_FILE=/opt/hermes/hermes.env
HERMES_HOME=/home/hermes/.hermes
HERMES_ENV="${HERMES_HOME}/.env"
HERMES_CONFIG="${HERMES_HOME}/config.yaml"
SETUP_DONE_MARKER="${HERMES_HOME}/provider-configured"

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

write_env_file_kv() {
    local file="$1" key="$2" val="$3" tmp
    tmp="${file}.tmp"
    touch "$file"
    grep -v "^${key}=" "$file" >"$tmp" 2>/dev/null || : >"$tmp"
    printf '%s=%q\n' "$key" "$val" >>"$tmp"
    mv "$tmp" "$file"
    chmod 600 "$file"
}

GRADIENT_KEY=$(read_config_value GRADIENT_KEY || true)
GRADIENT_MODEL=$(read_config_value GRADIENT_MODEL || true)

if ! env_value_usable "$GRADIENT_KEY"; then
    exit 1
fi

if ! env_value_usable "$GRADIENT_MODEL"; then
    GRADIENT_MODEL="minimax-m2.5"
fi

mkdir -p "$HERMES_HOME"
chown hermes:hermes "$HERMES_HOME"
chmod 700 "$HERMES_HOME"

write_env_file_kv "$ENV_FILE" GRADIENT_KEY "$GRADIENT_KEY"
write_env_file_kv "$ENV_FILE" GRADIENT_MODEL "$GRADIENT_MODEL"
write_env_file_kv "$HERMES_ENV" MODEL_ACCESS_KEY "$GRADIENT_KEY"

python3 - "$HERMES_CONFIG" "$GRADIENT_MODEL" <<'PY'
import json
import sys

path, model = sys.argv[1], sys.argv[2]
config = {
    "model": {
        "provider": "custom",
        "default": model,
        "base_url": "https://inference.do-ai.run/v1",
        "api_key": "${MODEL_ACCESS_KEY}",
    },
    "custom_providers": [
        {
            "name": "digitalocean-gradient",
            "base_url": "https://inference.do-ai.run/v1",
            "key_env": "MODEL_ACCESS_KEY",
            "api_mode": "chat_completions",
            "models": [model],
        }
    ],
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY

printf '%s\n' "DigitalOcean Gradient" > "$SETUP_DONE_MARKER"
chown -R hermes:hermes "$HERMES_HOME"
chmod 600 "$HERMES_ENV" "$HERMES_CONFIG" "$SETUP_DONE_MARKER"

echo "Hermes configured for DigitalOcean Gradient: ${GRADIENT_MODEL}"
exit 0
