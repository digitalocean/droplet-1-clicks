#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install LogStash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

sudo apt-get --assume-yes install apt-transport-https

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt-get --assume-yes update && sudo NEEDRESTART_MODE=a apt-get --assume-yes install logstash

# Set permissions for logstash logs
sudo chmod 755 -R /var/log/logstash/

ufw limit ssh

ufw --force enable
