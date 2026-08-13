#!/usr/bin/env bash
# Unit tests for /opt/openclaw-cli.sh gateway-token injection allowlist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="$SCRIPT_DIR/../files/opt/openclaw-cli.sh"

if [ ! -f "$CLI" ]; then
    echo "FAIL: missing $CLI"
    exit 1
fi

eval "$(sed -n '/^openclaw_cli_accepts_gateway_token()/,/^}/p' "$CLI")"

FAILURES=0

assert_accepts_token() {
    local cmd="$1"
    if openclaw_cli_accepts_gateway_token "$cmd"; then
        echo "OK: $cmd receives --token"
    else
        echo "FAIL: $cmd should receive --token"
        FAILURES=$((FAILURES + 1))
    fi
}

assert_rejects_token() {
    local cmd="$1"
    if openclaw_cli_accepts_gateway_token "$cmd"; then
        echo "FAIL: $cmd should not receive --token"
        FAILURES=$((FAILURES + 1))
    else
        echo "OK: $cmd does not receive --token"
    fi
}

echo "=== openclaw-cli.sh token allowlist ==="

# Gateway RPC commands still need the injected token.
assert_accepts_token agent
assert_accepts_token devices
assert_accepts_token tui
assert_accepts_token status
assert_accepts_token gateway

# agents is local config management (add/list/bind/delete); --token is rejected.
assert_rejects_token agents
assert_rejects_token skills
assert_rejects_token configure
assert_rejects_token onboard

if [ "$FAILURES" -ne 0 ]; then
    echo
    echo "$FAILURES assertion(s) failed"
    exit 1
fi

echo
echo "All assertions passed"
