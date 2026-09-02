#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

EXA_VERSION="${application_version:?application_version is required}"

echo "==> Installing Node.js 20 (Nodesource)..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "==> Installing Caddy (reverse proxy with shortlived TLS)..."
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
# Keep Caddy off until 001_onboot installs the shortlived Caddyfile (avoids stock :80 page).
systemctl disable --now caddy || true

echo "==> Installing Exa MCP Server ${EXA_VERSION}..."
npm install -g "exa-mcp-server@${EXA_VERSION}"

PKG_ROOT="$(npm root -g)/exa-mcp-server"
if [ ! -f "${PKG_ROOT}/smithery/shttp/index.cjs" ] \
  && [ ! -f "${PKG_ROOT}/.smithery/shttp/index.cjs" ] \
  && [ ! -f "${PKG_ROOT}/shttp/.smithery/index.cjs" ]; then
  echo "Error: streamable HTTP bundle (smithery/shttp) not found for exa-mcp-server@${EXA_VERSION}" >&2
  exit 1
fi

echo "==> Creating Exa config directory..."
mkdir -p /etc/exa
chmod 700 /etc/exa
echo "${EXA_VERSION}" > /etc/exa/version
chmod 644 /etc/exa/version

echo "==> Setting helper script permissions..."
chmod +x /opt/setup-exa.sh
chmod +x /opt/setup-exa-domain.sh
chmod +x /opt/status-exa.sh
chmod +x /opt/update-exa.sh
chmod +x /opt/start-exa.sh
chmod +x /opt/stop-exa.sh
chmod +x /opt/restart-exa.sh
chmod +x /opt/run-exa-mcp.sh
chmod +x /opt/run-exa-mcp-http.sh
chmod +x /opt/render-exa-caddy.sh
chmod +x /opt/rotate-exa-access-token.sh
chmod +x /opt/write-exa-access-creds.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl daemon-reload
# Enable only after API key setup (/opt/setup-exa.sh) or when already configured on boot.

# Verify the global binary is on PATH
if ! command -v exa-mcp-server >/dev/null 2>&1; then
  echo "Error: exa-mcp-server binary not found after install"
  exit 1
fi

echo "==> Cleaning up setup environment..."
apt-get autoremove -y
apt-get clean

echo "Exa MCP Server ${EXA_VERSION} installation complete."
