#!/bin/bash
echo "Restarting OpenClaw Gateway..."
systemctl restart openclaw

# Wait a moment for the service to start
sleep 2

# Check status
if systemctl is-active --quiet openclaw; then
    echo "✅ OpenClaw restarted successfully!"
    echo "Gateway is running on port 18789"
    echo "View logs with: journalctl -u openclaw -f"
else
    echo "❌ Error: Failed to restart OpenClaw"
    echo "Check logs with: journalctl -u openclaw -xe"
    exit 1
fi
