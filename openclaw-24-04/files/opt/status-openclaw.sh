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
echo "  If UI/CLI breaks after update (e.g. schema version / sessions unavailable),"
echo "  stop the gateway first, then repair with external service policy"
echo "  (1-Click openclaw.service is not CLI-managed):"
echo "    sudo systemctl stop openclaw"
echo "    sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \\"
echo "      openclaw doctor --fix --yes --non-interactive"
echo "    sudo systemctl start openclaw"
echo "    Optional: sudo /opt/ensure-openclaw-ready.sh"
echo "              sudo /opt/apply-inference-from-env.sh   # if models list empty"
if [ -f /opt/openclaw.env ]; then
    cur=$(grep -E '^OPENCLAW_VERSION=' /opt/openclaw.env 2>/dev/null | tail -n 1 | cut -d'=' -f2- || true)
    [ -n "$cur" ] && echo "  Current pin:      ${cur}"
fi
