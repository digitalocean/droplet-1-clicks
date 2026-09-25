#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-1.16.0}"
OPENHANDS_USER=openhands
OPENHANDS_HOME=/home/openhands

ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw limit ssh/tcp

# Agent Canvas serves ingress on :8000 across all interfaces and upstream has no
# bind-to-loopback option (its agent-server and automation backends do pass
# --host 127.0.0.1). Deny :8000 explicitly rather than relying on the default
# incoming policy: UFW matches rules in order, so this keeps the ingress private
# even if someone later relaxes the default or appends an allow rule. Loopback is
# accepted in before.rules, so Caddy and SSH tunnels are unaffected.
ufw deny 8000/tcp comment 'Agent Canvas ingress: reach via Caddy on 443'

ufw --force enable

# Node.js 24 (Agent Canvas 1.16 needs >=22.12.0, 1.17+ needs >=24)
# Use a signed apt keyring instead of curling a remote setup script into bash.
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
  > /etc/apt/sources.list.d/nodesource.list
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

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

# systemd ExecStart is /usr/local/bin/agent-canvas. Link the package file, not
# `command -v` (PATH prefers /usr/local/bin and ln -sfn onto itself is circular).
CANVAS_MJS="$(npm prefix -g)/lib/node_modules/@openhands/agent-canvas/bin/agent-canvas.mjs"
if [ ! -e "$CANVAS_MJS" ]; then
  echo "ERROR: ${CANVAS_MJS} not found after npm install." >&2
  exit 1
fi
ln -sfn "$CANVAS_MJS" /usr/local/bin/agent-canvas
/usr/local/bin/agent-canvas --version || true

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
chmod +x /opt/apply-inference-from-env.sh
chmod +x /opt/retry-apply-inference-after-cloud-init.sh
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
