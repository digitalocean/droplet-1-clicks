#!/bin/bash

set -euo pipefail

export HERDR_INSTALL_DIR=/usr/local/bin
export PATH="/usr/local/bin:${PATH}"

echo "Updating Herdr to the latest stable release..."
systemctl stop herdr.service || true
curl -fsSL https://herdr.dev/install.sh | sh
systemctl start herdr.service
herdr --version
echo "Herdr updated. Reattach with: herdr"
