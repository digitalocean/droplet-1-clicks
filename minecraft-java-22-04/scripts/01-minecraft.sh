#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt update
sudo apt install -y openjdk-17-jre-headless

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

wget https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar -P /opt/minecraft

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
chown -R minecraft:minecraft /opt/minecraft/eula.txt
chown -R minecraft:minecraft /opt/minecraft/server.jar
