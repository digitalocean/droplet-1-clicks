#!/bin/bash

set -e

# Configure UFW firewall - SSH only (no web interface)
ufw limit ssh/tcp
ufw --force enable
echo "Firewall configured successfully."

# Install OpenCode via official install script with version pinning
# Uses --no-modify-path so we control PATH via /etc/profile.d
export PATH="/root/.opencode/bin:$PATH"
curl -fsSL https://opencode.ai/install | bash -s -- --version "${application_version}" --no-modify-path

# Ensure OpenCode is in PATH for all users (install script uses ~/.opencode/bin for root)
mkdir -p /etc/profile.d
cat > /etc/profile.d/opencode.sh << 'EOF'
# OpenCode - add to PATH for all login shells
if [ -d /root/.opencode/bin ]; then
  export PATH="/root/.opencode/bin:$PATH"
fi
EOF
chmod 644 /etc/profile.d/opencode.sh

# Verify installation
if command -v opencode >/dev/null 2>&1; then
  echo "OpenCode installed successfully: $(opencode --version 2>/dev/null || echo 'version check skipped')"
else
  # May not be in PATH in this shell context; verify binary exists
  if [ -f /root/.opencode/bin/opencode ]; then
    echo "OpenCode binary installed at /root/.opencode/bin/opencode"
  else
    echo "Error: OpenCode installation may have failed"
    exit 1
  fi
fi

# Make helper scripts, MOTD, and onboot script executable (copied by Packer)
chmod +x /opt/update-opencode.sh
chmod +x /opt/opencode-version.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "OpenCode installation complete."
