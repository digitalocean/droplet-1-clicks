#!/bin/bash
echo "Starting T3 Code..."
systemctl start t3code
systemctl start caddy
sleep 2
if systemctl is-active --quiet t3code; then
  echo "T3 Code started successfully."
else
  echo "Failed to start T3 Code. Check: journalctl -u t3code -xe"
  exit 1
fi
