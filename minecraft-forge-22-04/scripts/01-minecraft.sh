#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt update
sudo apt install -y openjdk-18-jre-headless
sudo apt install -y openjdk-18-jdk-headless

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

wget https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar -P /opt/minecraft

echo "eula=true" > /opt/minecraft/eula.txt

wget https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.2-48.1.0/forge-1.20.2-48.1.0-installer.jar -P /opt/minecraft

chown -R minecraft:minecraft /opt/minecraft
chown -R minecraft:minecraft /opt/minecraft/eula.txt
chown -R minecraft:minecraft /opt/minecraft/server.jar

sudo -u minecraft java -jar /opt/minecraft/forge-1.20.2-48.1.0-installer.jar --installServer

ufw limit ssh
ufw allow 25565/tcp
ufw allow 25565/udp

ufw --force enable
