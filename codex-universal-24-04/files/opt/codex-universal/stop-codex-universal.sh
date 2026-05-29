#!/bin/bash
set -e

echo "Stopping Codex Universal..."
systemctl stop codex-universal
echo "Codex Universal stopped."
