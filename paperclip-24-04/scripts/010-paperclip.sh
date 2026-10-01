#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-2026.916.1}"
# Normalize optional leading "v" from release tags
APP_VERSION="${APP_VERSION#v}"

export DEBIAN_FRONTEND=noninteractive

# Node.js 24 (Paperclip requires >=24.11.0)
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
  > /etc/apt/sources.list.d/nodesource.list
apt-get update -y
apt-get install -y nodejs

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

# Ensure paperclip user's PATH includes managed shim location
if ! grep -q '\.local/bin' /home/paperclip/.profile 2>/dev/null; then
  cat >> /home/paperclip/.profile <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
  chown paperclip:paperclip /home/paperclip/.profile
fi

echo "Installing managed Paperclip CLI (${APP_VERSION})..."
su - paperclip -c "npx --registry https://registry.npmjs.org paperclipai install --version ${APP_VERSION} --yes"

# Verify managed shim
if [ ! -x /home/paperclip/.local/bin/paperclipai ]; then
  echo "ERROR: managed paperclipai shim missing after install" >&2
  exit 1
fi
su - paperclip -c "paperclipai --version" || true

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
chmod +x /opt/setup-paperclip-domain.sh
chmod +x /opt/write-paperclip-config.sh
chmod +x /opt/claim-paperclip-admin.sh
chmod +x /opt/apply-inference-from-env.sh
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
