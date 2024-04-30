#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt update
sudo apt install -y openjdk-17-jre-headless

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

wget https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/496/downloads/paper-1.20.4-496.jar -P /opt/minecraft

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
chown -R minecraft:minecraft /opt/minecraft/eula.txt
chown -R minecraft:minecraft /opt/minecraft/paper-1.20.4-496.jar
