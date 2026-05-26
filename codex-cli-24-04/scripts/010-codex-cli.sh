#!/bin/bash

set -e

# Configure UFW firewall - SSH only (no web interface)
ufw limit ssh/tcp
ufw --force enable
echo "Firewall configured successfully."

CODEX_VERSION="${application_version}"
CODEX_RELEASE="rust-v${CODEX_VERSION}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# shellcheck source=/dev/null
source /opt/codex-cli-download.sh

echo "Installing Codex CLI ${CODEX_VERSION} from GitHub release..."
install_codex_binaries "$CODEX_RELEASE" "$tmpdir" \
  "${codex_tarball_sha256:-}" "${bwrap_tarball_sha256:-}"

cat > /usr/local/bin/codex << 'EOF'
#!/bin/bash
# Load Gradient model access key when the shell profile has not been sourced yet.
if [ -f /etc/profile.d/codex-gradient.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/codex-gradient.sh
elif [ -f /root/.codex/env ]; then
  # shellcheck source=/dev/null
  . /root/.codex/env
fi
exec /usr/local/lib/codex/codex "$@"
EOF
chmod 0755 /usr/local/bin/codex

# Verify installation
if command -v codex >/dev/null 2>&1; then
  echo "Codex CLI installed successfully: $(codex --version 2>/dev/null || echo 'version check skipped')"
else
  echo "Error: Codex CLI installation failed"
  exit 1
fi

# Ensure Codex config directory exists
mkdir -p /root/.codex
chmod 600 /root/.codex/config.toml
chmod 600 /root/.codex/gradient-models.json

# Make helper scripts, MOTD, and onboot script executable (copied by Packer)
chmod +x /opt/codex-cli-download.sh
chmod +x /opt/update-codex-cli.sh
chmod +x /opt/codex-cli-version.sh
chmod +x /opt/setup-codex-cli.sh
chmod +x /opt/apply-gradient-from-env.sh
chmod 600 /opt/codex-cli.env
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "Codex CLI installation complete."
