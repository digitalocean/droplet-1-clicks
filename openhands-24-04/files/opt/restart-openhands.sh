#!/bin/bash
echo "Restarting OpenHands (Agent Canvas)..."
systemctl restart openhands
sleep 2
if systemctl is-active --quiet openhands; then
  echo "OpenHands restarted successfully."
  echo "View logs: journalctl -u openhands -f"
else
  echo "Failed to restart OpenHands. Check: journalctl -u openhands -xe"
  exit 1
fi
