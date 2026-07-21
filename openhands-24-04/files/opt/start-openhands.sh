#!/bin/bash
echo "Starting OpenHands (Agent Canvas)..."
systemctl start openhands
systemctl start caddy
sleep 2
if systemctl is-active --quiet openhands; then
  echo "OpenHands started successfully."
else
  echo "Failed to start OpenHands. Check: journalctl -u openhands -xe"
  exit 1
fi
