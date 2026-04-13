#!/bin/bash
echo "=== OpenClaw Gateway Status ==="
systemctl status openclaw --no-pager

echo ""
echo "=== Gateway Token ==="
if [ -f "/opt/openclaw.env" ]; then
    grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env | cut -d'=' -f2
else
    echo "Token not yet generated. Run the onboot script."
fi

echo ""
echo "=== Gateway URL ==="
myip=$(hostname -I | awk '{print$1}')
echo "http://$myip:18789"