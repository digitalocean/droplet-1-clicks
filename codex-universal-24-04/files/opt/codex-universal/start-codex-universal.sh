#!/bin/bash
set -e

echo "Starting Codex Universal..."
systemctl start codex-universal

if systemctl is-active --quiet codex-universal; then
    echo "Codex Universal started successfully."
    echo "Enter the environment with: /opt/codex-universal/shell-codex-universal.sh"
else
    echo "Failed to start Codex Universal. Check: systemctl status codex-universal"
    exit 1
fi
