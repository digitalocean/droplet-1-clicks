#!/bin/bash

set -e

# Configure UFW firewall - SSH only (no web interface)
ufw limit ssh/tcp
ufw --force enable
echo "Firewall configured successfully."

echo "Installing Kilo Code CLI ${application_version} from npm..."
npm install --global "@kilocode/cli@${application_version}"

# Verify installation
if command -v kilo >/dev/null 2>&1; then
  echo "Kilo Code CLI installed successfully: $(kilo --version 2>/dev/null || echo 'version check skipped')"
else
  echo "Error: Kilo Code CLI installation failed"
  exit 1
fi

# Make helper scripts, MOTD, and onboot script executable (copied by Packer)
chmod +x /opt/apply-digitalocean-token.sh
chmod +x /opt/setup-kilocode.sh
chmod +x /opt/update-kilocode.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "Kilo Code CLI installation complete."
