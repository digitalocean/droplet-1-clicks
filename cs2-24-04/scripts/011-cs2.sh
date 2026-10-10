#!/bin/bash

# Create the linuxgsm user that will own the CS2 server
useradd --home-dir /home/linuxgsm \
        --shell /bin/bash \
        --create-home \
        --system \
        -G sudo \
        linuxgsm

chown -R linuxgsm: /home/linuxgsm

# Install LinuxGSM and set up the cs2server script
sudo -u linuxgsm bash -c "
  cd /home/linuxgsm
  wget -O linuxgsm.sh https://linuxgsm.sh
  chmod +x linuxgsm.sh
  bash linuxgsm.sh cs2server
"

# Run the CS2 server install: downloads SteamCMD and the CS2 dedicated server
# files (~30GB) via the LinuxGSM cs2server installer (App ID 730, anonymous login).
# Pipe 'yes' inside the subshell so it reaches cs2server's stdin directly,
# avoiding stdin forwarding issues across the sudo -u boundary.
sudo -u linuxgsm bash -c 'cd /home/linuxgsm && yes | ./cs2server install'

# Ensure the linuxgsm home directory is fully owned by the linuxgsm user
chown -R linuxgsm: /home/linuxgsm

# Make the per-instance onboot script executable
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
