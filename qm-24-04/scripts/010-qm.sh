#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Docker Engine + Compose plugin
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl enable docker
systemctl restart docker

docker --version
docker compose version

# Caddy reverse proxy (host TLS on the bare droplet IP; QM's portal stays on
# loopback :8081). QM's own sign-in flow requires HTTPS or literal
# "localhost" — see README.md "Why Caddy" — plain HTTP on a public IP is a
# hard dead end, not just a security nicety.
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy && chown -R caddy:caddy /var/log/caddy
systemctl stop caddy 2>/dev/null || true
systemctl disable caddy 2>/dev/null || true

# Pre-pull the pinned QM images so first boot is faster. Digests come from
# https://github.com/yc-software/qm/releases/download/${application_version}/images.json
echo "Pulling QM stack images (release ${application_version})..."
docker pull ghcr.io/yc-software/qm/core@sha256:24f58b9b72c4413c6004001be6844087169c855e6bd28d6a8bcc06d62faa5987
docker pull ghcr.io/yc-software/qm/web-ui@sha256:eb4fda23cbeba3b7884efdea8fc815558ecfecb1564c8e36f5c6b1ae6f742d8e
docker pull ghcr.io/yc-software/qm/portal@sha256:7f643afce9d67f7bc71f9b954c5257e77e40795f47d89d751fce6a8caf753806
docker pull docker.io/library/postgres:16

printf '%s\n' "${application_version}" > /srv/qm/.qm-version

# Materialize .env from the non-hidden Packer template (Packer may skip dotfiles)
if [ -f /srv/qm/env.template ]; then
  cp /srv/qm/env.template /srv/qm/.env
  chmod 600 /srv/qm/.env
fi

# Convenience symlink matching this repo's other 1-clicks (/<app>.env)
ln -sfn /srv/qm/.env /srv/qm.env

chmod +x /srv/qm/gen-secrets.py
chmod +x /srv/qm/start-qm.sh
chmod +x /srv/qm/stop-qm.sh
chmod +x /srv/qm/restart-qm.sh
chmod +x /srv/qm/status-qm.sh
chmod +x /srv/qm/update-qm.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl enable fail2ban
systemctl restart fail2ban

echo "QM (release ${application_version}) installation complete."
echo "Stack will start on first boot after secrets are generated."
