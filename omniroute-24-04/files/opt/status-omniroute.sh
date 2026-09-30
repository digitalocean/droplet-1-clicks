#!/bin/bash
echo "=== OmniRoute Service Status ==="
systemctl status omniroute --no-pager || true

echo ""
echo "=== Docker Compose ==="
/opt/omniroute/run.sh status || true

echo ""
echo "=== Caddy Status ==="
systemctl is-active caddy >/dev/null 2>&1 && echo "caddy: active" || echo "caddy: inactive"

echo ""
echo "=== Admin password ==="
if [ -f /opt/omniroute/.env ]; then
  grep "^INITIAL_PASSWORD=" /opt/omniroute/.env | cut -d= -f2-
else
  echo "Env file missing."
fi

echo ""
echo "=== Endpoints ==="
pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
priv=$(hostname -I | awk '{print $1}')
host="${pub:-$priv}"
echo "  Dashboard: https://${host}/   (Caddy -> OmniRoute on 127.0.0.1:20128)"
echo "  API:       https://${host}/v1"
echo "  Loopback:  http://127.0.0.1:20128"
