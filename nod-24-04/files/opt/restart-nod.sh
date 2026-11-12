#!/bin/bash
set -euo pipefail

echo "Restarting Nod..."
/opt/nod-compose.sh up -d --force-recreate --wait --wait-timeout 300
echo "Nod restarted."
