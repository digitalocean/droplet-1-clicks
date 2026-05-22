#!/bin/bash

set -e

# Configure UFW firewall - SSH only (no web interface)
ufw limit ssh/tcp
ufw --force enable
echo "Firewall configured successfully."

CODEX_VERSION="${application_version}"
CODEX_RELEASE="rust-v${CODEX_VERSION}"
ARCH="x86_64-unknown-linux-musl"
CODEX_URL="https://github.com/openai/codex/releases/download/${CODEX_RELEASE}/codex-${ARCH}.tar.gz"
BWRAP_URL="https://github.com/openai/codex/releases/download/${CODEX_RELEASE}/bwrap-${ARCH}.tar.gz"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing Codex CLI ${CODEX_VERSION} from GitHub release..."
curl -fsSL "$CODEX_URL" -o "${tmpdir}/codex.tar.gz"
tar -xzf "${tmpdir}/codex.tar.gz" -C "${tmpdir}"
install -m 0755 "${tmpdir}/codex-${ARCH}" /usr/local/bin/codex

echo "Installing bwrap sandbox helper..."
curl -fsSL "$BWRAP_URL" -o "${tmpdir}/bwrap.tar.gz"
tar -xzf "${tmpdir}/bwrap.tar.gz" -C "${tmpdir}"
install -m 0755 "${tmpdir}/bwrap-${ARCH}" /usr/local/bin/bwrap

# Verify installation
if command -v codex >/dev/null 2>&1; then
  echo "Codex CLI installed successfully: $(codex --version 2>/dev/null || echo 'version check skipped')"
else
  echo "Error: Codex CLI installation failed"
  exit 1
fi

# Ensure Codex config directory exists
mkdir -p /root/.codex

# Make helper scripts, MOTD, and onboot script executable (copied by Packer)
chmod +x /opt/update-codex-cli.sh
chmod +x /opt/codex-cli-version.sh
chmod +x /opt/setup-codex-cli.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "Codex CLI installation complete."
