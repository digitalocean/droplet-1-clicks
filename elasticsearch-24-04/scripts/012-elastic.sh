#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install ElasticSearch
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

sudo apt-get --assume-yes install apt-transport-https

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list

# Prevent package postinst from starting ES during the image build. A first
# start here would bake node identity / HTTP certs into the snapshot and then
# break first boot after we wipe the data directory.
cat >/usr/sbin/policy-rc.d <<'EOF'
#!/bin/sh
exit 101
EOF
chmod 755 /usr/sbin/policy-rc.d

# Install the package at image-build time so first boot does not pay apt cost
sudo apt-get --assume-yes update
sudo NEEDRESTART_MODE=a apt-get --assume-yes install elasticsearch

rm -f /usr/sbin/policy-rc.d

# Single-node Droplet: bind publicly and skip multi-node bootstrap checks
cat >> /etc/elasticsearch/elasticsearch.yml <<EOM
network.host: 0.0.0.0
discovery.type: single-node
EOM

sudo chmod 755 -R /var/log/elasticsearch/

# Ensure the service is enabled for boot, but do not leave it running or with
# first-start security/data artifacts baked into the snapshot.
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service
sudo systemctl stop elasticsearch.service || true
sudo rm -rf /var/lib/elasticsearch/*
sudo mkdir -p /var/lib/elasticsearch
sudo chown elasticsearch:elasticsearch /var/lib/elasticsearch
# Drop any auto-config TLS material from an accidental start so each Droplet
# bootstraps security fresh on first boot.
sudo rm -rf /etc/elasticsearch/certs

# Allow elasticsearch port
ufw limit ssh
ufw allow 9200

ufw --force enable
