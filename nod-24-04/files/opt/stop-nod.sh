#!/bin/bash
set -euo pipefail

echo "Stopping Nod..."
/opt/nod-compose.sh down
echo "Nod stopped."
