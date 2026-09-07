#!/bin/bash
# Configure ZeroClaw Schema V3 config for headless 1-Click setup.
# Usage: zeroclaw-run-onboard.sh <api_key> <provider> <model>
#
# ZeroClaw 0.8.x deprecated `zeroclaw onboard --force --provider ...` (flags error).
# Interactive `zeroclaw quickstart` requires a TTY, so Marketplace setup writes
# a minimal Schema V3 config.toml directly instead.
set -euo pipefail

API_KEY="${1:?api_key required}"
PROVIDER="${2:?provider required}"
MODEL="${3:?model required}"

CONFIG_DIR=/home/zeroclaw/.zeroclaw
CONFIG_FILE="${CONFIG_DIR}/config.toml"
AGENT_ALIAS=assistant
RISK_ALIAS=locked_down
ONBOARD_LOG=/tmp/zeroclaw-onboard.log

toml_escape() {
    # Escape for double-quoted TOML strings.
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

resolve_provider() {
    # Sets: FAMILY ALIAS URI PROVIDER_REF
    FAMILY=""
    ALIAS=""
    URI=""
    PROVIDER_REF=""

    case "$PROVIDER" in
        custom:http://*|custom:https://*)
            FAMILY=custom
            ALIAS=digitalocean
            URI="${PROVIDER#custom:}"
            PROVIDER_REF="custom.digitalocean"
            ;;
        openai|anthropic|openrouter)
            FAMILY="$PROVIDER"
            ALIAS=default
            URI=""
            PROVIDER_REF="${PROVIDER}.default"
            ;;
        *)
            echo "Unsupported provider '${PROVIDER}'." >&2
            echo "Expected openai, anthropic, openrouter, or custom:https://..." >&2
            exit 1
            ;;
    esac
}

write_schema_v3_config() {
    local key_esc model_esc uri_esc
    key_esc=$(toml_escape "$API_KEY")
    model_esc=$(toml_escape "$MODEL")

    umask 077
    mkdir -p "$CONFIG_DIR"

    {
        cat <<EOF
schema_version = 3

[providers.models.${FAMILY}.${ALIAS}]
api_key = "${key_esc}"
model = "${model_esc}"
temperature = 0.7
EOF
        if [ -n "$URI" ]; then
            uri_esc=$(toml_escape "$URI")
            printf 'uri = "%s"\n' "$uri_esc"
        fi

        cat <<EOF

[agents.${AGENT_ALIAS}]
model_provider = "${PROVIDER_REF}"
risk_profile = "${RISK_ALIAS}"

[risk_profiles.${RISK_ALIAS}]
level = "supervised"
workspace_only = true
allowed_commands = ["git", "npm", "cargo", "ls", "cat", "grep", "find", "echo", "pwd", "wc", "head", "tail", "date"]
require_approval_for_medium_risk = true
block_high_risk_commands = true
sandbox_enabled = true

[memory]
backend = "sqlite"
auto_save = true
embedding_provider = "none"

[gateway]
port = 42617
host = "127.0.0.1"
require_pairing = true
allow_public_bind = false
web_dist_dir = "/usr/share/zeroclawlabs/web/dist"

[secrets]
encrypt = true

[onboard_state]
quickstart_completed = true
EOF
    } >"$CONFIG_FILE"

    chmod 600 "$CONFIG_FILE"
    chown zeroclaw:zeroclaw "$CONFIG_FILE" "$CONFIG_DIR"
}

validate_config() {
    # Prefer config list (loads + validates). Fall back to status if unavailable.
    local rc
    set +e
    su - zeroclaw -c '/usr/local/bin/zeroclaw config list' >"$ONBOARD_LOG" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        su - zeroclaw -c '/usr/local/bin/zeroclaw status' >"$ONBOARD_LOG" 2>&1
        rc=$?
    fi
    set -e

    if [ "$rc" -ne 0 ]; then
        echo "ZeroClaw rejected the generated config (exit ${rc}). Log: ${ONBOARD_LOG}" >&2
        tail -n 40 "$ONBOARD_LOG" >&2 || true
        exit 1
    fi

    if ! grep -qE "^\[providers\.models\.${FAMILY}\.${ALIAS}\]" "$CONFIG_FILE"; then
        echo "Missing providers.models.${FAMILY}.${ALIAS} in ${CONFIG_FILE}" >&2
        exit 1
    fi
    if ! grep -qE "^\[agents\.${AGENT_ALIAS}\]" "$CONFIG_FILE"; then
        echo "Missing agents.${AGENT_ALIAS} in ${CONFIG_FILE}" >&2
        exit 1
    fi
}

resolve_provider
write_schema_v3_config
validate_config

echo "Configured provider ${PROVIDER_REF} model ${MODEL} agent ${AGENT_ALIAS}" >"$ONBOARD_LOG"
