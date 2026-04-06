#!/bin/bash
echo "Restarting ZeroClaw..."
systemctl restart zeroclaw

sleep 2

if systemctl is-active --quiet zeroclaw; then
    echo "ZeroClaw restarted successfully!"
    echo "Gateway is running on port 42617"
    echo "View logs with: journalctl -u zeroclaw -f"
else
    echo "Error: Failed to restart ZeroClaw"
    echo "Check logs with: journalctl -u zeroclaw -xe"
    exit 1
fi
