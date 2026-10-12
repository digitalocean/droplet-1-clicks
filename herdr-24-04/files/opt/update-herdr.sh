#!/bin/bash

set -euo pipefail

export HERDR_INSTALL_DIR=/usr/local/bin
export PATH="/usr/local/bin:${PATH}"

# shellcheck source=/dev/null
source /opt/run-remote-installer.sh

echo "Updating Herdr to the latest stable release..."
systemctl stop herdr.service || true
run_remote_installer https://herdr.dev/install.sh sh
systemctl start herdr.service
herdr --version
echo "Herdr updated. Reattach with: herdr"
