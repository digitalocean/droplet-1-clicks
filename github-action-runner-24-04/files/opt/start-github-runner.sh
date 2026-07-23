#!/bin/bash
echo "Starting GitHub Actions Runner..."
systemctl start actions-runner
sleep 1
if systemctl is-active --quiet actions-runner; then
  echo "GitHub Actions Runner started successfully."
else
  echo "Failed to start. Is the runner registered? (.runner must exist)"
  echo "Check: journalctl -u actions-runner -xe"
  echo "Register with: /etc/setup-github-runner.sh"
  exit 1
fi
