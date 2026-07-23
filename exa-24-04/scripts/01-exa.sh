#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

EXA_VERSION="${application_version:?application_version is required}"

echo "==> Configuring UFW (SSH only; Exa MCP uses stdio, no HTTP UI)..."
ufw limit ssh/tcp
ufw --force enable

echo "==> Installing Node.js 20 (Nodesource)..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "==> Installing Exa MCP Server ${EXA_VERSION}..."
npm install -g "exa-mcp-server@${EXA_VERSION}"

echo "==> Creating Exa config directory..."
mkdir -p /etc/exa
chmod 700 /etc/exa
echo "${EXA_VERSION}" > /etc/exa/version
chmod 644 /etc/exa/version

echo "==> Setting helper script permissions..."
chmod +x /opt/setup-exa.sh
chmod +x /opt/status-exa.sh
chmod +x /opt/update-exa.sh
chmod +x /opt/run-exa-mcp.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Verify the global binary is on PATH
if ! command -v exa-mcp-server >/dev/null 2>&1; then
  echo "Error: exa-mcp-server binary not found after install"
  exit 1
fi

echo "==> Cleaning up setup environment..."
apt-get autoremove -y
apt-get clean

echo "Exa MCP Server ${EXA_VERSION} installation complete."
