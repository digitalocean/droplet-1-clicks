#!/bin/sh

# Install Docker Compose plugin from Docker's official repository
apt-get -y update
apt-get -y install docker-compose-plugin
systemctl start docker
systemctl enable docker

# Clone a pinned Supabase release for stable self-hosting
mkdir -p /srv/supabase
cd /srv/supabase
git clone --depth 1 --branch "$supabase_repo_ref" https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env

# Install SSL tooling
snap install core && snap refresh core
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

chmod +x /var/supabase/supabase-setup.sh

grep -qxF '/var/supabase/supabase-setup.sh' /root/.bashrc || cat >> /root/.bashrc <<EOM
/var/supabase/supabase-setup.sh
EOM
