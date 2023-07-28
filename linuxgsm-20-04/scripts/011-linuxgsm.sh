#!/bin/sh

sudo dpkg --add-architecture i386
sudo apt update
echo "Y" | sudo apt install lib32gcc1 lib32stdc++6 libsdl2-2.0-0:i386

 # allow port for Query and RCON
 ufw allow 27015/tcp

 # allow port for Game
 ufw allow 27015/udp

 # allow port for SourceTV
 ufw allow 27020/udp

 # allow port for Client
 ufw allow 27005/udp

# Create the linuxgsm user
useradd --home-dir /home/linuxgsm \
        --shell /bin/bash \
        --create-home \
        --system \
        linuxgsm

# Setup the home directory
chown -R linuxgsm: /home/linuxgsm

