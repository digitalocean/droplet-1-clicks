#!/bin/bash
# Surface ZeroClaw gateway pairing code (OpenHands MOTD / OpenClaw pairing helper style).
# Usage:
#   /opt/show-zeroclaw-pairing.sh           # print current code
#   /opt/show-zeroclaw-pairing.sh --new     # request a fresh code when supported
set -euo pipefail

PORT="${ZEROCLAW_GATEWAY_PORT:-42617}"
WANT_NEW=0
[ "${1-}" = "--new" ] && WANT_NEW=1

if ! systemctl is-active --quiet zeroclaw 2>/dev/null; then
  echo "ZeroClaw service is not running. Start it with: systemctl start zeroclaw" >&2
  exit 1
fi

extract_code() {
  local text="$1"
  # JSON field variants
  printf '%s' "$text" | sed -n 's/.*"pairing_code"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

print_code() {
  local code="$1" source="$2"
  [ -n "$code" ] || return 1
  echo "Gateway pairing code: ${code}"
  echo "(source: ${source})"
  echo "Enter this code at https://$(hostname -I | awk '{print $1}')/agent"
  umask 077
  printf '%s\n' "$code" > /root/.zeroclaw_pairing_code
  chmod 600 /root/.zeroclaw_pairing_code
  return 0
}

# 1) Official CLI when available
if [ "$WANT_NEW" -eq 1 ]; then
  cli_out=$(su - zeroclaw -c "zeroclaw gateway get-paircode --new" 2>/dev/null || true)
else
  cli_out=$(su - zeroclaw -c "zeroclaw gateway get-paircode" 2>/dev/null || true)
fi
if [ -n "$cli_out" ]; then
  code=$(extract_code "$cli_out")
  if [ -z "$code" ]; then
    # Plain-text CLI output — print as-is if it looks useful
    if printf '%s\n' "$cli_out" | grep -qiE 'pair|code|[0-9A-Za-z-]{4,}'; then
      echo "$cli_out"
      echo "$cli_out" | grep -Eo '[0-9A-Za-z-]{4,}' | head -n1 > /root/.zeroclaw_pairing_code 2>/dev/null || true
      chmod 600 /root/.zeroclaw_pairing_code 2>/dev/null || true
      exit 0
    fi
  elif print_code "$code" "zeroclaw gateway get-paircode"; then
    exit 0
  fi
fi

# 2) Local HTTP admin / public pair endpoints
urls=(
  "http://127.0.0.1:${PORT}/pair/code"
  "http://127.0.0.1:${PORT}/admin/paircode"
)
if [ "$WANT_NEW" -eq 1 ]; then
  urls=(
    "http://127.0.0.1:${PORT}/admin/paircode/new"
    "http://127.0.0.1:${PORT}/pair/code"
    "http://127.0.0.1:${PORT}/admin/paircode"
  )
fi

for url in "${urls[@]}"; do
  if [ "$WANT_NEW" -eq 1 ] && [[ "$url" == *"/new" ]]; then
    resp=$(curl -fsS -X POST "$url" 2>/dev/null || true)
  else
    resp=$(curl -fsS "$url" 2>/dev/null || true)
  fi
  code=$(extract_code "$resp")
  if print_code "$code" "$url"; then
    exit 0
  fi
done

# 3) Cached code from a previous successful fetch
if [ -s /root/.zeroclaw_pairing_code ]; then
  echo "Gateway pairing code: $(cat /root/.zeroclaw_pairing_code)"
  echo "(source: /root/.zeroclaw_pairing_code — restart zeroclaw or re-run with --new if rejected)"
  exit 0
fi

echo "Could not read a pairing code." >&2
echo "Try: systemctl restart zeroclaw && sleep 2 && $0 --new" >&2
echo "Also check: journalctl -u zeroclaw -n 50 --no-pager" >&2
exit 1
