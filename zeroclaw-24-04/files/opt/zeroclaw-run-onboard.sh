#!/bin/bash
# Run zeroclaw onboard without placing API keys on the su(1) command line.
# Usage: zeroclaw-run-onboard.sh <api_key> <provider> <model>
set -euo pipefail

API_KEY="${1:?api_key required}"
PROVIDER="${2:?provider required}"
MODEL="${3:?model required}"

CONFIG_DIR=/home/zeroclaw/.zeroclaw
CONFIG_FILE="${CONFIG_DIR}/config.toml"
CRED_FILE="${CONFIG_DIR}/.onboard-credentials"

umask 077
mkdir -p "$CONFIG_DIR"
printf 'ZEROCLAW_API_KEY=%q\n' "$API_KEY" >"$CRED_FILE"
chmod 600 "$CRED_FILE"
chown zeroclaw:zeroclaw "$CRED_FILE" "$CONFIG_DIR"

onboard_cmd=$(
    printf 'set -a; . %q; set +a; exec /usr/local/bin/zeroclaw onboard --force --provider %q --model %q' \
        "$CRED_FILE" "$PROVIDER" "$MODEL"
)
su - zeroclaw -c "$onboard_cmd" >/dev/null 2>&1

rm -f "$CRED_FILE"

if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/^port = .*/port = 42617/' "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    chown zeroclaw:zeroclaw "$CONFIG_FILE"
fi
