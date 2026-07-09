#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt update
sudo apt install -y openjdk-21-jre-headless curl

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

mkdir -p /opt/minecraft

PAPER_URL=$(curl -fsSL -H "User-Agent: digitalocean-droplet-1-clicks/1.0 (marketplace@digitalocean.com)" \
  "https://fill.papermc.io/v3/projects/paper/versions/1.21.4/builds/224" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['downloads']['server:default']['url'])")

wget -q "${PAPER_URL}" -O /opt/minecraft/paper-1.21.4-224.jar

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
chown -R minecraft:minecraft /opt/minecraft/eula.txt
chown -R minecraft:minecraft /opt/minecraft/paper-1.21.4-224.jar
