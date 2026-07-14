#!/bin/sh

# Create the superset user
useradd --home-dir /home/superset \
        --shell /bin/bash \
        --create-home \
        --system \
        superset

chown -R superset: /home/superset
chmod 755 /home/superset

VERSION=${application_version}

# Install Apache Superset into a dedicated virtualenv
cat > /tmp/install_superset.sh << EOF
cd /home/superset
mkdir -p superset-project
cd superset-project
python3 -m venv superset-env
. superset-env/bin/activate
pip install --upgrade pip setuptools wheel
pip install pillow apache-superset==${VERSION} psycopg2-binary gunicorn
EOF

chmod +x /tmp/install_superset.sh
chown superset:superset /tmp/install_superset.sh
sudo -s -u superset /tmp/install_superset.sh
rm /tmp/install_superset.sh

mkdir -p /home/superset/superset
cp /var/superset/superset_config.py /home/superset/superset/superset_config.py
chown -R superset:superset /home/superset/superset

chmod +x /var/superset/superset.sh
chmod +x /var/superset/superset-setup.sh
chmod +x /var/lib/digitalocean/finish-setup.sh
chmod +x /var/lib/digitalocean/setup-dbaas.sh

# Install SSL tooling (same pattern as supabase-22-04)
snap install core && snap refresh core
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

# Prompt for domain/SSL on first interactive login
cat >> /root/.bashrc <<EOM
/var/superset/superset-setup.sh
EOM
