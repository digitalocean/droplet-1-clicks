#!/bin/bash
# DigitalOcean 1-Click: SSH is root, but the gateway runs as user "zeroclaw".
# The dashboard tells operators to run `zeroclaw gateway get-paircode --new`,
# which otherwise looks for /root/.zeroclaw/data/gateway-admin.token and fails.
# When invoked as root, re-run the real binary as the service user.
set -euo pipefail

REAL_BIN=/usr/local/lib/zeroclaw/zeroclaw
SERVICE_USER=zeroclaw

if [ ! -x "$REAL_BIN" ]; then
  echo "ZeroClaw binary missing at ${REAL_BIN}" >&2
  exit 127
fi

if [ "$(id -u)" -eq 0 ] && id -u "$SERVICE_USER" >/dev/null 2>&1; then
  cmd=$(printf '%q ' "$REAL_BIN" "$@")
  exec su - "$SERVICE_USER" -c "$cmd"
fi

exec "$REAL_BIN" "$@"
