#!/bin/bash
set -euo pipefail

echo "Updating Hermes Agent..."
/opt/hermes/hermes-cli.sh update
echo ""
echo "Hermes update complete."
