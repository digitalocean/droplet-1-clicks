#!/bin/bash
set -e

echo "Restarting Codex Universal..."
systemctl restart codex-universal
echo "Codex Universal restarted."
echo "Enter the environment with: /opt/codex-universal/shell-codex-universal.sh"
