#!/bin/sh

#install docker-compose
apt-get -y install docker.io
apt -y install docker-compose
systemctl start docker
systemctl enable docker


#clone supabase project
mkdir /srv/supabase
cd /srv/supabase
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env

# install SSL
snap install core && snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

chmod +x /var/supabase/supabase-setup.sh
cat >> /root/.bashrc <<EOM
/var/supabase/supabase-setup.sh
EOM
