#!/bin/bash

# Coolify initialization script
# This script runs before Coolify starts to set up SSH keys for localhost management

set -e

SSH_KEY_PATH="/data/coolify/ssh/keys/id.root@host.docker.internal"

# Check if SSH key already exists (skip if already initialized)
if [ -f "${SSH_KEY_PATH}" ]; then
    echo "SSH keys already exist, skipping generation..."
    exit 0
fi

echo "Generating SSH keys for Coolify localhost management..."

# Generate SSH key for Coolify server management (unique per droplet)
ssh-keygen -f "${SSH_KEY_PATH}" -t ed25519 -N '' -C root@coolify

# Add the public key to authorized_keys
cat "${SSH_KEY_PATH}.pub" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo "SSH keys configured successfully."

# Reapply proper permissions
chown -R 9999:root /data/coolify
chmod -R 700 /data/coolify

echo "Coolify SSH initialization complete."
