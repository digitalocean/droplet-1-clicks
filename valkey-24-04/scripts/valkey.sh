#!/bin/sh

# open port for clients
ufw allow 6379
ufw limit ssh/tcp
ufw --force enable

# Get the latest version of valkey
tag_version=$(curl -s "https://api.github.com/repos/valkey-io/valkey/releases/latest" | jq -r '.tag_name')
echo "Latest version of valkey is $tag_version"

#clone valkey project
mkdir /srv
cd /srv
git clone https://github.com/valkey-io/valkey.git
cd valkey
git fetch --tags
git checkout tags/$tag_version

# build valkey
make distclean

# install valkey
make install

# Create valkey user
useradd --system --home /var/lib/valkey --shell /bin/false valkey

# Create necessary directories
mkdir -p /var/lib/valkey
mkdir -p /var/log/valkey
mkdir -p /etc/valkey

# Set ownership
chown valkey:valkey /var/lib/valkey
chown valkey:valkey /var/log/valkey

# Create valkey configuration file (password will be set by onboot script)
cat > /etc/valkey/valkey.conf << EOF
bind 127.0.0.1
port 6379
timeout 0
requirepass PLACEHOLDER_PASSWORD
save 900 1
save 300 10
save 60 10000
rdbcompression yes
dbfilename dump.rdb
dir /var/lib/valkey
logfile /var/log/valkey/valkey.log
loglevel notice
daemonize no
supervised systemd
EOF

# Create systemd service file
cat > /etc/systemd/system/valkey.service << EOF
[Unit]
Description=Valkey In-Memory Data Store
After=network.target

[Service]
User=valkey
Group=valkey
ExecStart=/usr/local/bin/valkey-server /etc/valkey/valkey.conf
ExecStop=/bin/sh -c '/usr/local/bin/valkey-cli -a \$(grep valkey_password /root/.digitalocean_passwords | cut -d"=" -f2 | tr -d "\"") shutdown'
TimeoutStopSec=0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start valkey service
systemctl daemon-reload
systemctl enable valkey
systemctl start valkey