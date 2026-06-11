#!/bin/bash

# Install droplet-agent if it is not present. The agent is purged from the
# snapshot during the image build, and on the desktop image cloud-init's
# first-boot agent install can fail (NetworkManager races cloud-init), so
# this runs as a systemd service with retries instead.

LOG=/var/log/droplet_agent_install.log

if [ -x /opt/digitalocean/bin/droplet-agent ]; then
    echo "droplet-agent already installed" >> "$LOG"
    exit 0
fi

for i in $(seq 1 30); do
    if curl -fsSL https://repos-droplet.digitalocean.com/install.sh | bash >> "$LOG" 2>&1; then
        echo "droplet-agent installed on attempt $i" >> "$LOG"
        exit 0
    fi
    echo "attempt $i failed, retrying in 10s" >> "$LOG"
    sleep 10
done

echo "droplet-agent install failed after 30 attempts" >> "$LOG"
exit 1
