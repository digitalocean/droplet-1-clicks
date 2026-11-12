#!/bin/bash
set -euo pipefail

echo "Starting Nod..."
/opt/nod-compose.sh up -d --wait --wait-timeout 300
echo "Nod started."
