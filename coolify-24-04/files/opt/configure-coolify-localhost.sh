#!/bin/bash

# Coolify Localhost Activation Script
# This script activates SSH keys for Coolify to manage the localhost server

set -e

echo "=================================================="
echo "Coolify Localhost Server Activation"
echo "=================================================="
echo ""

SSH_KEY_PATH="/data/coolify/ssh/keys/id.root@host.docker.internal"

# Check if Coolify is running
if ! docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml \
  ps | grep -q "coolify"; then
    echo "Error: Coolify is not running."
    echo "Please start Coolify first: systemctl start coolify"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "SSH keys not found. Generating new keys..."
    mkdir -p "$(dirname "${SSH_KEY_PATH}")"
    ssh-keygen -f "${SSH_KEY_PATH}" -t ed25519 -N '' -C root@coolify -q
    chown -R 9999:root /data/coolify/ssh
    chmod -R 700 /data/coolify/ssh
    echo "✓ SSH keys generated"
else
    echo "✓ SSH keys found at ${SSH_KEY_PATH}"
fi

echo ""

# Check if key is already in authorized_keys
if grep -q "root@coolify" /root/.ssh/authorized_keys 2>/dev/null; then
    echo "Localhost is already activated!"
    echo ""
    echo "You can now use Coolify to deploy applications on this server."
    exit 0
fi

# Add the public key to authorized_keys
echo "Activating localhost access..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat "${SSH_KEY_PATH}.pub" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo "✓ SSH key added to authorized_keys"
echo ""

# Restart Coolify to pick up the changes
echo "Restarting Coolify to apply changes..."
systemctl restart coolify
echo "✓ Coolify restarted"
echo ""

echo "=================================================="
echo "Localhost Activation Complete!"
echo "=================================================="
echo ""
echo "Your Coolify localhost server is now ready to use."
echo ""
echo "Next steps:"
echo "1. Go to your Coolify dashboard at http://$(hostname -I | awk '{print$1}'):8000"
echo "2. Navigate to 'Servers' in the sidebar"
echo "3. The localhost server should now show as connected"
echo "4. You can now deploy applications, databases, and services!"
echo ""
