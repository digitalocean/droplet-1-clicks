#!/bin/bash
echo "=== OpenHands Service Status ==="
systemctl status openhands --no-pager || true

echo ""
echo "=== Caddy Status ==="
systemctl is-active caddy >/dev/null 2>&1 && echo "caddy: active" || echo "caddy: inactive"

echo ""
echo "=== API Key ==="
if [ -f /opt/openhands.env ]; then
  grep "^LOCAL_BACKEND_API_KEY=" /opt/openhands.env | cut -d= -f2-
else
  echo "Env file missing."
fi

echo ""
echo "=== Web UI ==="
pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
priv=$(hostname -I | awk '{print $1}')
host="${pub:-$priv}"
echo "  https://${host}/   (Caddy -> Agent Canvas on :8000; UFW denies 8000)"
echo "  Loopback (SSH tunnel): http://127.0.0.1:8000"

echo ""
echo "=== Update OpenHands ==="
echo "  Latest:           sudo /opt/update-openhands.sh"
echo "  Specific version: sudo /opt/update-openhands.sh <version>   # e.g. 1.16.0"
echo "  List versions:    sudo /opt/update-openhands.sh --list"
echo "  Rollback:         sudo /opt/update-openhands.sh --rollback"
echo "                    # reinstalls the version from before the last update;"
echo "                    # for any other pin, use the specific-version command"
if [ -f /opt/openhands.env ]; then
  prev=$(grep -E '^OPENHANDS_VERSION_PREVIOUS=' /opt/openhands.env 2>/dev/null | tail -n 1 | cut -d= -f2- || true)
  cur=$(grep -E '^OPENHANDS_VERSION=' /opt/openhands.env 2>/dev/null | tail -n 1 | cut -d= -f2- || true)
  [ -n "$cur" ] && echo "  Current pin:      ${cur}"
  [ -n "$prev" ] && echo "  Previous pin:     ${prev}"
fi
