#!/bin/bash
# Run zeroclaw onboard without placing API keys on the su(1) command line.
# Usage: zeroclaw-run-onboard.sh <api_key> <provider> <model>
#
# Always ensures top-level api_key in config.toml (OpenHands-style direct config
# write). Upstream onboard alone has left api_keys=[] with no usable api_key.
set -euo pipefail

API_KEY="${1:?api_key required}"
PROVIDER="${2:?provider required}"
MODEL="${3:?model required}"

CONFIG_DIR=/home/zeroclaw/.zeroclaw
CONFIG_FILE="${CONFIG_DIR}/config.toml"
CRED_FILE="${CONFIG_DIR}/.onboard-credentials"
ONBOARD_LOG=/tmp/zeroclaw-onboard.log

ensure_config_api_key() {
    local key="$1" conf="$CONFIG_FILE"
    [ -f "$conf" ] || return 1
    if grep -qE '^api_key\s*=' "$conf"; then
        sed -i "s|^api_key\s*=.*|api_key = \"${key}\"|" "$conf"
    else
        sed -i "1i api_key = \"${key}\"" "$conf"
    fi
    if grep -qE '^default_provider\s*=' "$conf"; then
        sed -i "s|^default_provider\s*=.*|default_provider = \"${PROVIDER}\"|" "$conf"
    fi
    if grep -qE '^default_model\s*=' "$conf"; then
        sed -i "s|^default_model\s*=.*|default_model = \"${MODEL}\"|" "$conf"
    fi
    chown zeroclaw:zeroclaw "$conf"
    chmod 600 "$conf"
}

umask 077
mkdir -p "$CONFIG_DIR"
printf 'ZEROCLAW_API_KEY=%q\n' "$API_KEY" >"$CRED_FILE"
chmod 600 "$CRED_FILE"
chown zeroclaw:zeroclaw "$CRED_FILE" "$CONFIG_DIR"

onboard_cmd=$(
    printf 'set -a; . %q; set +a; exec /usr/local/bin/zeroclaw onboard --force --provider %q --model %q' \
        "$CRED_FILE" "$PROVIDER" "$MODEL"
)

# Keep onboard output for debugging (do not swallow failures silently).
set +e
su - zeroclaw -c "$onboard_cmd" >"$ONBOARD_LOG" 2>&1
onboard_rc=$?
set -e

rm -f "$CRED_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "zeroclaw onboard did not create ${CONFIG_FILE} (exit ${onboard_rc}). Log: ${ONBOARD_LOG}" >&2
    if [ -f /etc/config/digitalocean-gradient.toml ] && [[ "$PROVIDER" == custom:* ]]; then
        cp /etc/config/digitalocean-gradient.toml "$CONFIG_FILE"
    else
        exit 1
    fi
fi

sed -i 's/^port = .*/port = 42617/' "$CONFIG_FILE" || true
ensure_config_api_key "$API_KEY"

# Verify top-level api_key is non-empty (ignore reliability api_keys = []).
configured_key=$(grep -E '^api_key\s*=' "$CONFIG_FILE" | head -n1 | sed 's/^api_key\s*=\s*"\?\([^"]*\)"\?.*/\1/')
if [ -z "$configured_key" ] || [ "$configured_key" = "PLACEHOLDER" ]; then
    echo "Failed to write api_key into ${CONFIG_FILE}. Onboard log: ${ONBOARD_LOG}" >&2
    exit 1
fi

chmod 600 "$CONFIG_FILE"
chown zeroclaw:zeroclaw "$CONFIG_FILE"
