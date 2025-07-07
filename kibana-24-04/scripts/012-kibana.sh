#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install Kibana
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

sudo apt-get install apt-transport-https

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list

sudo apt-get update && sudo apt-get install kibana


# Set host for the Kibana server
cat >> /etc/kibana/kibana.yml <<EOM
server.host: "0.0.0.0"
EOM

# Set permissions for Kibana logs
sudo chmod 755 -R /var/log/kibana/

# Start elastic service
sudo systemctl daemon-reload

sudo systemctl enable kibana.service

sudo systemctl start kibana.service

# Allow elasticsearch port
ufw limit ssh
ufw allow 5601

ufw --force enable
