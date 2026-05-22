#!/bin/bash
# Run OpenClaw CLI as the openclaw user (arguments preserved and shell-safe).
# Injects --token from /opt/openclaw.env only for gateway RPC commands (devices,
# tui, status, …). Subcommands like `skills` do not accept --token.

OPENCLAW_BIN=${OPENCLAW_BIN:-/usr/bin/openclaw}

read_gateway_token_from_env() {
    local line val
    [ -f /opt/openclaw.env ] || return 1
    line=$(grep -E '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env 2>/dev/null | tail -n 1) || return 1
    eval "val=${line#OPENCLAW_GATEWAY_TOKEN=}"
    case "$val" in
        ''|*'${'*|PLACEHOLDER*) return 1 ;;
    esac
    printf '%s' "$val"
}

# openclaw subcommands that talk to the gateway and accept --token
openclaw_cli_accepts_gateway_token() {
    case "${1:-}" in
        devices|tui|status|cron|gateway|health|logs|agent|agents|sessions|browser)
            return 0
            ;;
    esac
    return 1
}

args_have_token=0
for a in "$@"; do
    case "$a" in
        --token|--token=*) args_have_token=1 ;;
    esac
done

cli_args=("$@")
if [ "$args_have_token" -eq 0 ] && openclaw_cli_accepts_gateway_token "${1:-}"; then
    token=$(read_gateway_token_from_env || true)
    if [ -n "$token" ]; then
        cli_args+=(--token="$token")
    fi
fi

if [ "${#cli_args[@]}" -eq 0 ]; then
    if [ "$(id -un)" = "openclaw" ]; then
        exec "$OPENCLAW_BIN"
    fi
    exec su - openclaw -c "$(printf '%q' "$OPENCLAW_BIN")"
fi

if [ "$(id -un)" = "openclaw" ]; then
    exec "$OPENCLAW_BIN" "${cli_args[@]}"
fi

cmd="$(printf '%q' "$OPENCLAW_BIN")"
for a in "${cli_args[@]}"; do
    cmd+=" $(printf '%q' "$a")"
done
exec su - openclaw -c "$cmd"
