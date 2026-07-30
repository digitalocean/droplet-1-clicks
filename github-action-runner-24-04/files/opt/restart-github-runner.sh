#!/bin/bash
echo "Restarting GitHub Actions Runner..."
systemctl restart actions-runner
sleep 1
if systemctl is-active --quiet actions-runner; then
  echo "GitHub Actions Runner restarted successfully."
else
  echo "Failed to restart. Check: journalctl -u actions-runner -xe"
  exit 1
fi
