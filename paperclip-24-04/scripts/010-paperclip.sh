#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-2026.1117.0}"
# Normalize optional leading "v" from release tags
APP_VERSION="${APP_VERSION#v}"
# Pins from template.json (passed by Packer)
export NODE_VERSION="${node_version:-24.22.3}"
export OPENCODE_VERSION="${opencode_version:-1.19.6}"

export DEBIAN_FRONTEND=noninteractive

# Node.js pin at /usr/bin/node before paperclipai install pins the shim.
chmod +x /opt/ensure-paperclip-node.sh
/opt/ensure-paperclip-node.sh
chmod +x /opt/ensure-paperclip-opencode.sh
/opt/ensure-paperclip-opencode.sh
node --version
npm --version

# Caddy reverse proxy (host TLS; Paperclip listens on loopback :3100)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

# Local PostgreSQL — authenticated/public refuses embedded Postgres fallback
if ! command -v psql >/dev/null 2>&1; then
  apt-get install -y postgresql
fi
systemctl enable postgresql
systemctl start postgresql
# Wait for cluster (package postinst / first start can lag briefly)
for _ in $(seq 1 30); do
  if sudo -u postgres pg_isready -q; then
    break
  fi
  sleep 1
done
if ! sudo -u postgres pg_isready -q; then
  echo "ERROR: PostgreSQL did not become ready during image bake" >&2
  systemctl status postgresql --no-pager -l >&2 || true
  exit 1
fi
# Role + DB created at bake; password is set per-droplet on first boot
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='paperclip'" | grep -q 1; then
  sudo -u postgres createuser paperclip
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='paperclip'" | grep -q 1; then
  sudo -u postgres createdb -O paperclip paperclip
fi
# Temporary bake-time password (replaced on first boot); allows TCP auth smoke checks
sudo -u postgres psql -v ON_ERROR_STOP=1 -c \
  "ALTER USER paperclip WITH PASSWORD 'PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT';" >/dev/null
echo "PostgreSQL ready (role/db: paperclip)."

# Dedicated runtime user
useradd -m -s /bin/bash paperclip || true
mkdir -p /home/paperclip/.local/bin
chown -R paperclip:paperclip /home/paperclip

# Ensure paperclip user's PATH includes managed shim location.
# umask 022: @paperclipai/server Copilot postinstall rejects group-writable binaries.
if ! grep -q '\.local/bin' /home/paperclip/.profile 2>/dev/null; then
  cat >> /home/paperclip/.profile <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
umask 022
EOF
  chown paperclip:paperclip /home/paperclip/.profile
elif ! grep -qE '^umask 022' /home/paperclip/.profile 2>/dev/null; then
  printf '\numask 022\n' >> /home/paperclip/.profile
  chown paperclip:paperclip /home/paperclip/.profile
fi

echo "Installing managed Paperclip CLI (${APP_VERSION})..."
# Use the official managed installer so install.json / shim stay compatible with
# `paperclipai update`. umask 022 is required: @paperclipai/server postinstall
# rejects group-writable Copilot binaries (Ubuntu user umask 002 → 775 →
# "Copilot executable has unsafe permissions"). Log to a file because Packer
# often drops Node's block-buffered stdout on failure.
SHIM=/home/paperclip/.local/bin/paperclipai
INSTALL_LOG=/tmp/paperclipai-managed-install.log
install -d -o paperclip -g paperclip -m 755 /home/paperclip/.local /home/paperclip/.local/bin

if ! su - paperclip -c "umask 022; PATH=/usr/bin:/bin:\$HOME/.local/bin \
  npm exec --yes --registry=https://registry.npmjs.org --package=paperclipai@${APP_VERSION} -- \
  paperclipai install --version ${APP_VERSION} --yes" >"$INSTALL_LOG" 2>&1; then
  echo "ERROR: paperclipai install failed for ${APP_VERSION} (see ${INSTALL_LOG})" >&2
  tail -n 120 "$INSTALL_LOG" >&2 || true
  exit 1
fi

if [ ! -x "$SHIM" ]; then
  echo "ERROR: managed paperclipai shim missing after install" >&2
  tail -n 80 "$INSTALL_LOG" >&2 || true
  exit 1
fi
/opt/ensure-paperclip-node.sh
if ! grep -q "exec '/usr/bin/node' " "$SHIM"; then
  echo "ERROR: paperclipai shim is not pinned to /usr/bin/node" >&2
  exit 1
fi
su - paperclip -c "PATH=/usr/bin:/bin:\$HOME/.local/bin paperclipai --version" || true
echo "Installed managed paperclipai ${APP_VERSION}."

# Materialize env from Packer template (Packer may skip hidden .env files)
if [ -f /opt/paperclip/env.template ]; then
  cp /opt/paperclip/env.template /opt/paperclip.env
fi
if [ -f /opt/paperclip.env ]; then
  sed -i "s|^PAPERCLIP_VERSION=.*|PAPERCLIP_VERSION=${APP_VERSION}|" /opt/paperclip.env
  chmod 600 /opt/paperclip.env
fi

systemctl enable fail2ban
systemctl restart fail2ban

# Helper scripts and MOTD
chmod +x /opt/start-paperclip.sh
chmod +x /opt/stop-paperclip.sh
chmod +x /opt/restart-paperclip.sh
chmod +x /opt/status-paperclip.sh
chmod +x /opt/update-paperclip.sh
chmod +x /opt/ensure-paperclip-node.sh
chmod +x /opt/ensure-paperclip-opencode.sh
chmod +x /opt/setup-paperclip-domain.sh
chmod +x /opt/write-paperclip-config.sh
chmod +x /opt/claim-paperclip-admin.sh
chmod +x /opt/apply-inference-from-env.sh
chmod +x /opt/bootstrap-paperclip-do-agent.sh
chmod +x /opt/retry-apply-inference-after-cloud-init.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
mkdir -p /opt/paperclip

systemctl daemon-reload
systemctl enable paperclip
systemctl enable caddy

# Do not start Paperclip during image bake — first boot writes per-droplet secrets/config
systemctl stop paperclip 2>/dev/null || true
systemctl stop caddy 2>/dev/null || true

echo "Paperclip (${APP_VERSION}) installation complete."
echo "Stack will start on first boot after secrets and public URL are generated."
