#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-1.4.0}"
OPENHANDS_USER=openhands
OPENHANDS_HOME=/home/openhands

# HTTP/HTTPS via Caddy; Agent Canvas ingress stays on loopback :8000
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw limit ssh/tcp
ufw --force enable

# Node.js 22 (required by Agent Canvas)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Caddy reverse proxy
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

# Dedicated application user
useradd -m -s /bin/bash "$OPENHANDS_USER" || true
mkdir -p "$OPENHANDS_HOME/.openhands" "$OPENHANDS_HOME/projects" "$OPENHANDS_HOME/.local/bin"
chown -R openhands:openhands "$OPENHANDS_HOME"
chmod 0700 "$OPENHANDS_HOME/.openhands"

# uv for agent-server / automation (uvx)
su - "$OPENHANDS_USER" -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
# Ensure uv is on PATH for non-login systemd sessions
if [ -x "$OPENHANDS_HOME/.local/bin/uv" ]; then
  ln -sfn "$OPENHANDS_HOME/.local/bin/uv" /usr/local/bin/uv
  ln -sfn "$OPENHANDS_HOME/.local/bin/uvx" /usr/local/bin/uvx
fi

# Install Agent Canvas (OpenHands product UI)
npm install -g "@openhands/agent-canvas@${APP_VERSION}"

if ! command -v agent-canvas >/dev/null 2>&1; then
  echo "ERROR: agent-canvas not found on PATH after npm install." >&2
  exit 1
fi

# Stable absolute path for systemd ExecStart
CANVAS_BIN="$(command -v agent-canvas)"
ln -sfn "$CANVAS_BIN" /usr/local/bin/agent-canvas
agent-canvas --version || true

# Persist version into env template
if [ -f /opt/openhands.env ]; then
  sed -i "s|\${APP_VERSION}|${APP_VERSION}|g" /opt/openhands.env
  chmod 600 /opt/openhands.env
fi

systemctl enable fail2ban
systemctl restart fail2ban

# Helper scripts and MOTD
chmod +x /opt/restart-openhands.sh
chmod +x /opt/status-openhands.sh
chmod +x /opt/update-openhands.sh
chmod +x /opt/start-openhands.sh
chmod +x /opt/stop-openhands.sh
chmod +x /opt/apply-gradient-from-env.sh
chmod +x /opt/retry-apply-gradient-after-cloud-init.sh
chmod +x /opt/setup-openhands-domain.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Enable but do not start yet — first boot generates secrets and starts services
systemctl daemon-reload
systemctl enable openhands
systemctl enable caddy

echo "OpenHands (Agent Canvas ${APP_VERSION}) installation complete."
echo "Service will start on first boot after secrets are generated."
