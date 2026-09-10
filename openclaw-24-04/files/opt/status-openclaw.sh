#!/bin/bash
echo "=== OpenClaw Gateway Status ==="
systemctl status openclaw --no-pager

echo ""
echo "=== Gateway Token ==="
if [ -f "/opt/openclaw.env" ]; then
    grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env | cut -d'=' -f2-
else
    echo "Token not yet generated. Run the onboot script."
fi

echo ""
echo "=== Control UI (browser) ==="
pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
priv=$(hostname -I | awk '{print $1}')
host="${pub:-$priv}"
echo "  https://${host}/   (Caddy -> gateway on port 18789)"
echo "  Direct loopback URL (SSH tunnel only): http://127.0.0.1:18789"

echo ""
echo "=== Update OpenClaw ==="
echo "  Latest:           sudo /opt/update-openclaw.sh"
echo "  Specific version: sudo /opt/update-openclaw.sh v2026.9.3"
echo "  Rollback:         sudo /opt/update-openclaw.sh --rollback"
if [ -f /opt/openclaw.env ]; then
    prev=$(grep -E '^OPENCLAW_VERSION_PREVIOUS=' /opt/openclaw.env 2>/dev/null | tail -n 1 | cut -d'=' -f2- || true)
    cur=$(grep -E '^OPENCLAW_VERSION=' /opt/openclaw.env 2>/dev/null | tail -n 1 | cut -d'=' -f2- || true)
    [ -n "$cur" ] && echo "  Current pin:      ${cur}"
    [ -n "$prev" ] && echo "  Previous pin:     ${prev}"
fi