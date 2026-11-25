#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install ElasticSearch
# Package is installed on first boot (001_onboot). That script enforces the
# CVE-2026-114938 (Java4Shell) package floor via apt-cache candidates (not
# hard-coded equality pins), applies the JVM mitigation, and unlocks SSH via
# EXIT trap so setup failures cannot brick login.
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

sudo apt-get --assume-yes install apt-transport-https

echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-9.x.list

# Allow elasticsearch port
ufw limit ssh
ufw allow 9200

ufw --force enable

