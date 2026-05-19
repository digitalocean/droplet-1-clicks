#!/bin/bash
# Fix gateway tokens in openclaw.json and ensure sandbox image exists (run as root on a live droplet).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

chmod +x /opt/sync-openclaw-gateway.sh /opt/build-openclaw-sandbox.sh

if [ ! -f /home/openclaw/.openclaw/openclaw.json ]; then
    echo "Missing /home/openclaw/.openclaw/openclaw.json — run setup or apply-gradient first." >&2
    exit 1
fi

/opt/sync-openclaw-gateway.sh
/opt/build-openclaw-sandbox.sh

chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 600 /home/openclaw/.openclaw/openclaw.json

systemctl restart openclaw

echo ""
echo "Gateway tokens in openclaw.json:"
jq -r '.gateway.auth.token, .gateway.remote.token' /home/openclaw/.openclaw/openclaw.json
echo ""
echo "Sandbox image:"
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^openclaw-sandbox:' || true
echo ""
echo "OpenClaw service:"
systemctl is-active openclaw
