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
echo "  https://${host}/   (Caddy -> Agent Canvas on 127.0.0.1:8000)"
echo "  Loopback (SSH tunnel): http://127.0.0.1:8000"
