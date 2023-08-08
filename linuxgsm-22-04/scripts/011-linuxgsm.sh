#!/bin/sh

sudo dpkg --add-architecture i386
sudo apt update
echo "Y" | sudo apt install lib32gcc1 lib32stdc++6 libsdl2-2.0-0:i386

# Create the linuxgsm user
sudo useradd --home-dir /home/linuxgsm \
            --shell /bin/bash \
            --create-home \
            --system \
            -G sudo \
            linuxgsm

# Setup the home directory
chown -R linuxgsm: /home/linuxgsm

