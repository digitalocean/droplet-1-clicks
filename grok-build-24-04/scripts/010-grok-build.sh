#!/bin/bash

set -e

# Configure UFW firewall - SSH only (no web interface)
ufw limit ssh/tcp
ufw --force enable
echo "Firewall configured successfully."

# Grok Build installs into $HOME/.grok/bin. During the Packer build HOME=/root,
# so the binary lands in /root/.grok/bin. Pin the version controlled by the
# template so rebuilds are reproducible.
export GROK_BIN_DIR="/root/.grok/bin"
mkdir -p "$GROK_BIN_DIR"

echo "Installing Grok Build ${application_version} via the official installer..."
curl -fsSL https://x.ai/cli/install.sh | bash -s -- "${application_version}"

# Ensure grok is on PATH for all login shells (the installer only edits
# /root/.bashrc; profile.d covers every user and non-interactive logins).
mkdir -p /etc/profile.d
cat > /etc/profile.d/grok-build.sh << 'EOF'
# Grok Build CLI
if [ -d "$HOME/.grok/bin" ]; then
  export PATH="$HOME/.grok/bin:$PATH"
elif [ -d /root/.grok/bin ]; then
  export PATH="/root/.grok/bin:$PATH"
fi
# Load a stored xAI API key (written by the setup wizard / onboot) if present.
if [ -f /etc/profile.d/grok-build-key.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/grok-build-key.sh
fi
EOF
chmod 644 /etc/profile.d/grok-build.sh

# Verify installation
export PATH="$GROK_BIN_DIR:$PATH"
if [ -x "$GROK_BIN_DIR/grok" ]; then
  echo "Grok Build installed successfully: $("$GROK_BIN_DIR/grok" --version 2>/dev/null || echo 'version check skipped')"
else
  echo "Error: Grok Build installation failed"
  exit 1
fi

# Ensure the Grok config directory exists with the pre-configured DigitalOcean
# Serverless Inference provider (copied by Packer). The installer appends a
# [cli] block to it.
mkdir -p /root/.grok
chmod 600 /root/.grok/config.toml

# Make helper scripts, MOTD, and onboot script executable (copied by Packer)
chmod +x /opt/setup-grok-build.sh
chmod +x /opt/update-grok-build.sh
chmod +x /opt/grok-login.sh
chmod +x /opt/apply-inference-from-env.sh
chmod 600 /opt/grok-build.env
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "Grok Build installation complete."
