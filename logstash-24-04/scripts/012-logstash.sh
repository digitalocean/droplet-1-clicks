#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install LogStash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg

sudo apt-get install apt-transport-https

echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-9.x.list

sudo apt-get update && sudo apt-get install logstash

# Set permissions for logstash logs
sudo chmod 755 -R /var/log/logstash/

ufw limit ssh

ufw --force enable
