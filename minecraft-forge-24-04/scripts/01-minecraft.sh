#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

wget https://piston-data.mojang.com/v1/objects/823e2250d24b3ddac457a60c92a6a941943fcd6a/server.jar -P /opt/minecraft

echo "eula=true" > /opt/minecraft/eula.txt

wget https://maven.minecraftforge.net/net/minecraftforge/forge/26.1.2-64.0.11/forge-26.1.2-64.0.11-installer.jar -P /opt/minecraft

chown -R minecraft:minecraft /opt/minecraft
chown -R minecraft:minecraft /opt/minecraft/eula.txt
chown -R minecraft:minecraft /opt/minecraft/server.jar

sudo -u minecraft java -jar /opt/minecraft/forge-26.1.2-64.0.11-installer.jar --installServer

ufw limit ssh
ufw allow 25565/tcp
ufw allow 25565/udp

ufw --force enable
