#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install ElasticSearch
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

sudo apt-get --assume-yes install apt-transport-https

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt-get --assume-yes update && sudo NEEDRESTART_MODE=a apt-get --assume-yes install elasticsearch

# Set host for the ElasticSearch server
cat >> /etc/elasticsearch/elasticsearch.yml <<EOM
network.host: 0.0.0.0
EOM

# Set permissions for ElasticSearch logs
sudo chmod 755 -R /var/log/elasticsearch/

# Start elastic service
sudo systemctl daemon-reload

sudo systemctl enable elasticsearch.service

sudo systemctl start elasticsearch.service

# Allow elasticsearch port
ufw limit ssh
ufw allow 9200

ufw --force enable

