#!/bin/sh

# Install Docker Compose plugin from Docker's official repository
apt-get -y update
apt-get -y install docker-compose-plugin
systemctl start docker
systemctl enable docker

# Clone a pinned Supabase release for stable self-hosting
mkdir -p /srv/supabase
cd /srv/supabase
git clone --depth 1 --branch "$application_version" https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env

# Install SSL tooling
snap install core && snap refresh core
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

chmod +x /var/supabase/supabase-setup.sh \
  /var/lib/digitalocean/setup-dbaas.sh \
  /var/lib/digitalocean/prepare-logflare-ssl.sh \
  /var/lib/cloud/scripts/per-instance/001_onboot \
  /etc/update-motd.d/99-one-click

# Bake Logflare Managed-DB SSL patch into the image so first boot does not depend
# on a fragile docker pull during onboot.
/var/lib/digitalocean/prepare-logflare-ssl.sh /srv/supabase/supabase/docker
