#!/bin/bash
set -euo pipefail

# Create the superset user
if ! id -u superset >/dev/null 2>&1; then
  useradd --home-dir /home/superset \
          --shell /bin/bash \
          --create-home \
          --system \
          superset
fi

chown -R superset: /home/superset
chmod 755 /home/superset

# Install Apache Superset into a dedicated virtualenv (shipped installer)
chmod +x /var/superset/install-superset.sh
sudo -u superset env SUPERSET_VERSION="${application_version}" \
  bash /var/superset/install-superset.sh

mkdir -p /home/superset/superset
cp /var/superset/superset_config.py /home/superset/superset/superset_config.py
chown -R superset:superset /home/superset/superset

# Install Caddy (reverse proxy with shortlived TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

# Make shipped scripts executable
chmod +x /var/superset/superset.sh
chmod +x /var/superset/install-superset.sh
chmod +x /var/lib/digitalocean/finish-setup.sh
chmod +x /var/lib/digitalocean/setup-dbaas.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click
chmod +x /opt/start-superset.sh
chmod +x /opt/stop-superset.sh
chmod +x /opt/restart-superset.sh
chmod +x /opt/status-superset.sh
chmod +x /opt/update-superset.sh
chmod +x /opt/setup-superset-domain.sh

systemctl enable postgresql
systemctl enable caddy
systemctl enable superset

echo "Apache Superset ${application_version} installed."
