#!/bin/bash

set -e

echo "Starting Plex Media Server installation..."

systemctl enable docker
systemctl start docker

ufw allow 32400/tcp

mkdir -p /opt/plex/{config,transcode,media}

sed -i "s|PLEX_VERSION_PLACEHOLDER|${plex_version}|g" /opt/plex/docker-compose.yml

chmod +x /opt/start-plex.sh
chmod +x /opt/stop-plex.sh
chmod +x /opt/restart-plex.sh
chmod +x /opt/update-plex.sh
chmod +x /opt/claim-plex.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click

ln -sf /etc/nginx/sites-available/plex /etc/nginx/sites-enabled/plex
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

cd /opt/plex
docker compose pull --quiet

systemctl enable plex

echo "Plex Media Server installation completed."
