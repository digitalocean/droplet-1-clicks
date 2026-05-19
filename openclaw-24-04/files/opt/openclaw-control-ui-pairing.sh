#!/bin/bash
# Interactive Control UI pairing (browser + gateway token) or approve-only mode.
#
#   sudo /opt/openclaw-control-ui-pairing.sh              # full first-login flow
#   sudo /opt/openclaw-control-ui-pairing.sh --approve-only # approve pending only
#
set -euo pipefail

DOCS_MAIN="https://docs.clawd.bot/"
MARKER_BEGIN='# openclaw-24-04-control-ui-pairing BEGIN'
MARKER_END='# openclaw-24-04-control-ui-pairing END'
MARKER_RANGE_BEGIN='openclaw-24-04-control-ui-pairing BEGIN'
MARKER_RANGE_END='openclaw-24-04-control-ui-pairing END'

APPROVE_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --approve-only) APPROVE_ONLY=1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

if [ ! -t 0 ] && [ "$APPROVE_ONLY" -eq 0 ]; then
    echo "Control UI pairing needs an interactive terminal (SSH with TTY)." >&2
    echo "Run: sudo $0" >&2
    exit 1
fi

droplet_public_ip() {
    curl -fsS --retry 5 --retry-connrefused --max-time 3 \
        http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true
}

remove_pairing_bashrc_hook() {
    if [ -f /root/.bashrc ]; then
        sed -i "/${MARKER_RANGE_BEGIN}/,/${MARKER_RANGE_END}/d" /root/.bashrc
    fi
}

read_gateway_token() {
    local line val
    if [ -f /opt/openclaw.env ]; then
        line=$(grep -E '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env 2>/dev/null | tail -n 1) || true
        if [ -n "$line" ]; then
val="${line#OPENCLAW_GATEWAY_TOKEN=}"
val="${val#[\'\"]}"
val="${val%[\'\"]}"
            case "$val" in
                ''|*'${'*|PLACEHOLDER*) ;;
                *) printf '%s' "$val"; return 0 ;;
            esac
        fi
    fi
    if [ -f /home/openclaw/.openclaw/openclaw.json ]; then
        val=$(jq -r '.gateway.auth.token // .gateway.remote.token // empty' \
            /home/openclaw/.openclaw/openclaw.json 2>/dev/null || true)
        case "$val" in
            ''|null|*'${'*|PLACEHOLDER*) return 1 ;;
            *) printf '%s' "$val"; return 0 ;;
        esac
    fi
    return 1
}

wait_for_gateway() {
    local i code
    printf "Waiting for gateway to become ready..."
    for i in $(seq 1 60); do
        code=$(curl -so /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:18789/ 2>/dev/null || true)
        if [ "$code" != "000" ] && [ -n "$code" ]; then
            printf " ready.\n"
            return 0
        fi
        sleep 2
        printf "."
    done
    printf "\n"
    echo "Warning: gateway did not respond on port 18789 within 120s." >&2
    echo "Check: systemctl status openclaw" >&2
    return 1
}

approve_pending_devices() {
    local token="$1"
    local tmpfile attempt output rid approve_failed remaining

    if ! systemctl is-active --quiet openclaw; then
        echo "openclaw service is not active. Try: systemctl restart openclaw" >&2
        return 1
    fi

    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' RETURN

    for attempt in $(seq 1 10); do
        /opt/openclaw-cli.sh devices list --token="${token}" >"$tmpfile" 2>&1 || true
        output=$(sed -n '/Pending/,/Paired/p' "$tmpfile" 2>/dev/null || true)
        REQUEST_IDS=($(echo "$output" | grep -oE '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}' || true))

        if [ "${#REQUEST_IDS[@]}" -gt 0 ]; then
            approve_failed=0
            for rid in "${REQUEST_IDS[@]}"; do
                if ! /opt/openclaw-cli.sh devices approve "$rid" --token="${token}" >/dev/null 2>&1; then
                    approve_failed=1
                fi
            done
            if [ "$approve_failed" -eq 0 ]; then
                rm -f "$tmpfile"
                trap - RETURN
                return 0
            fi
        fi

        if [ "$attempt" -lt 10 ]; then
            echo "No pending request yet, retrying ($attempt/10)..."
            sleep 5
        fi
    done

    echo "No pending Control UI pairing requests were found." >&2
    echo "CLI output:" >&2
    cat "$tmpfile" >&2
    rm -f "$tmpfile"
    trap - RETURN
    return 1
}

# --- approve-only (non-interactive) ---
if [ "$APPROVE_ONLY" -eq 1 ]; then
  exec /opt/openclaw-approve-ui-pairing.sh
fi

# --- interactive flow ---
chmod +x /opt/sync-openclaw-gateway.sh 2>/dev/null || true
if [ -x /opt/sync-openclaw-gateway.sh ]; then
    /opt/sync-openclaw-gateway.sh || true
fi

GATEWAY_TOKEN=$(read_gateway_token || true)
if [ -z "$GATEWAY_TOKEN" ]; then
    echo "ERROR: OPENCLAW_GATEWAY_TOKEN is not set. Check /opt/openclaw.env and run:" >&2
    echo "  sudo /opt/sync-openclaw-gateway.sh" >&2
    exit 1
fi

DROPLET_PUBLIC_IP=$(droplet_public_ip)
DROPLET_PRIVATE_IP=$(hostname -I | awk '{print $1}')
if [ -n "$DROPLET_PUBLIC_IP" ]; then
    DASHBOARD_HOST="$DROPLET_PUBLIC_IP"
else
    DASHBOARD_HOST="$DROPLET_PRIVATE_IP"
fi
DASHBOARD_URL="https://${DASHBOARD_HOST}"

wait_for_gateway || true

printf "\nOpenClaw requires pairing the Control UI (dashboard) before it can be used.\n"
printf "Docs: %s\n" "${DOCS_MAIN}"
printf "To approve later without this wizard: sudo /opt/openclaw-approve-ui-pairing.sh\n\n"

while true; do
    read -r -p "Run Control UI pairing now? (yes/no): " yn
    case "${yn,,}" in
        yes|y) break ;;
        no|n)
            echo "Skipped pairing. Run when ready: sudo $0"
            exit 0
            ;;
        *) echo "Please type 'yes' or 'no'." ;;
    esac
done

printf '\n======================================\n'
printf '  Browser Pairing Setup\n'
printf '======================================\n\n'
printf "Open this link in your browser:\n\n"
printf '  \e]8;;%s\e\\%s\e]8;;\e\\\n\n' "$DASHBOARD_URL" "$DASHBOARD_URL"
printf "Gateway token (paste into the dashboard):\n\n"
printf "  %s\n\n" "${GATEWAY_TOKEN}"
printf "Steps:\n"
printf "  1. Open the URL above\n"
printf "  2. Paste the gateway token and click Connect\n"
printf "  3. You should see \"pairing required\" — that is expected\n\n"

while true; do
    read -r -p "Type 'continue' once you see 'pairing required' (continue/exit): " yn
    case "${yn,,}" in
        continue|c) break ;;
        exit|e)
            echo "Run pairing later: sudo $0"
            exit 0
            ;;
        *) echo "Please type 'continue' or 'exit'." ;;
    esac
done

printf "\nSearching for pairing requests...\n"
if approve_pending_devices "$GATEWAY_TOKEN"; then
    printf "Pairing approved. Refresh the Control UI in your browser.\n"
    printf "TUI: /opt/openclaw-tui.sh\n"
    remove_pairing_bashrc_hook
    exit 0
fi

echo "" >&2
echo "Automatic approval did not complete. Try:" >&2
echo "  1. Keep the dashboard open at ${DASHBOARD_URL}" >&2
echo "  2. Ensure the gateway token is pasted and you clicked Connect." >&2
echo "  3. sudo /opt/openclaw-approve-ui-pairing.sh" >&2
remove_pairing_bashrc_hook
exit 0
