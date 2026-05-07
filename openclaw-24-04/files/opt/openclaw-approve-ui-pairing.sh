#!/bin/bash
# Approve pending Control UI (browser) pairing after you open the dashboard,
# paste the gateway token, and see "pairing required".
#
# Run as root:  sudo /opt/openclaw-approve-ui-pairing.sh
# Docs: https://docs.clawd.bot/

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [ ! -r /opt/openclaw.env ]; then
  echo "Missing /opt/openclaw.env" >&2
  exit 1
fi

GATEWAY_TOKEN=$(grep '^OPENCLAW_GATEWAY_TOKEN=' /opt/openclaw.env | cut -d= -f2-)
if [ -z "$GATEWAY_TOKEN" ]; then
  echo "OPENCLAW_GATEWAY_TOKEN is not set in /opt/openclaw.env" >&2
  exit 1
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if ! systemctl is-active --quiet openclaw; then
  echo "openclaw service is not active. Try:" >&2
  echo "  sudo systemctl restart openclaw" >&2
  echo "  sudo journalctl -u openclaw -n 100 --no-pager" >&2
  exit 1
fi

echo "Waiting for local gateway (127.0.0.1:18789) to respond..."
for _ in $(seq 1 15); do
  code=$(curl -so /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:18789/ 2>/dev/null || true)
  if [ "$code" != "000" ] && [ -n "$code" ]; then
    break
  fi
  sleep 2
done

# Read pending requests with retries because gateway startup can lag.
for attempt in $(seq 1 10); do
  /opt/openclaw-cli.sh devices list --token="${GATEWAY_TOKEN}" >"$TMPFILE" 2>&1 || true

  OUTPUT=$(sed -n '/Pending/,/Paired/p' "$TMPFILE" 2>/dev/null || true)
  # UUID v4 pattern (same as setup wizard)
  REQUEST_IDS=($(echo "$OUTPUT" | grep -oE '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}' || true))
  if [ "${#REQUEST_IDS[@]}" -gt 0 ]; then
    break
  fi

  if grep -qi 'gateway timeout' "$TMPFILE"; then
    echo "Gateway timeout while listing devices (attempt $attempt/10), retrying..."
  elif [ "$attempt" -lt 10 ]; then
    echo "No pending requests yet (attempt $attempt/10), retrying..."
  fi
  sleep 2
done

if [ "${#REQUEST_IDS[@]}" -eq 0 ]; then
  echo "No pending Control UI pairing requests were found."
  echo ""
  echo "1. Open the dashboard in your browser (use your droplet public https URL)."
  echo "2. Paste the gateway token from: grep OPENCLAW_GATEWAY_TOKEN /opt/openclaw.env"
  echo "3. Click Connect — you should see \"pairing required\"."
  echo "4. Run this script again within ~60 seconds."
  echo ""
  echo "CLI output from devices list:"
  cat "$TMPFILE"
  exit 1
fi

approve_failed=0
for rid in "${REQUEST_IDS[@]}"; do
  echo "Approving pairing request: $rid"
  ok=false
  for _ in $(seq 1 3); do
    if /opt/openclaw-cli.sh devices approve "$rid" --token="${GATEWAY_TOKEN}" >/dev/null 2>&1; then
      ok=true
      break
    fi
    sleep 1
  done
  if [ "$ok" = false ]; then
    echo "Failed to approve request: $rid" >&2
    approve_failed=1
  fi
done

echo ""
if [ "$approve_failed" -ne 0 ]; then
  echo "Some approvals failed. Check gateway health/logs:" >&2
  echo "  sudo systemctl status openclaw --no-pager" >&2
  echo "  sudo journalctl -u openclaw -n 120 --no-pager" >&2
  exit 1
fi

# Verify no pending requests remain.
/opt/openclaw-cli.sh devices list --token="${GATEWAY_TOKEN}" >"$TMPFILE" 2>&1 || true
REMAINING=$(sed -n '/Pending/,/Paired/p' "$TMPFILE" | grep -oE '[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}' | wc -l | tr -d ' ')
if [ "${REMAINING:-0}" -gt 0 ]; then
  echo "Pairing requests are still pending ($REMAINING). Keep dashboard open and run again." >&2
  exit 1
fi

echo "Done. Refresh the Control UI tab in your browser."
