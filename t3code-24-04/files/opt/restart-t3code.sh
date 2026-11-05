#!/bin/bash
echo "Restarting T3 Code..."
systemctl restart t3code
sleep 2
if systemctl is-active --quiet t3code; then
  echo "T3 Code restarted successfully."
  echo "View logs: journalctl -u t3code -f"
else
  echo "Failed to restart T3 Code. Check: journalctl -u t3code -xe"
  exit 1
fi
