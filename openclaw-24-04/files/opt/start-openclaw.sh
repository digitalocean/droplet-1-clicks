#!/bin/bash
echo "Starting OpenClaw Gateway..."
systemctl start openclaw
systemctl start caddy
sleep 2
if systemctl is-active --quiet openclaw; then
    echo "OpenClaw started successfully."
    echo "Gateway is running on port 18789"
else
    echo "Failed to start OpenClaw. Check: journalctl -u openclaw -xe"
    exit 1
fi
