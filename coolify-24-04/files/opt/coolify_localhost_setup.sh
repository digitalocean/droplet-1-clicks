#!/bin/bash
#
# Coolify localhost activation script
#
# This interactive script runs on first SSH login and prompts the user
# to activate localhost server for Coolify deployments.

set -e

# Check if we've already run this
if [ -f /root/.coolify_localhost_configured ]; then
    # Clean up bashrc to prevent running again
    sed -i '/coolify_localhost_setup.sh/d' /root/.bashrc
    exit 0
fi

clear

cat << "EOF"
================================================================================
                       Coolify Localhost Setup
================================================================================

Welcome to your Coolify droplet!

Coolify has been installed and is running, but the localhost server needs to
be activated before you can deploy applications to it. Note: this is NOT 
recommended for production use, as running applications on the same server
as Coolify may lead to resource contention.

This setup will:
  • Activate SSH keys for localhost access
  • Restart Coolify to apply changes
  • Enable you to deploy applications immediately

You can add remote servers later for better isolation and scalability.

EOF

echo ""
read -p "Would you like to activate localhost now? (recommended) [Y/n]: " -r
echo ""

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Activating localhost server..."
    echo ""
    
    SSH_KEY_PATH="/data/coolify/ssh/keys/id.root@host.docker.internal"
    
    # Check if SSH key exists (should have been generated during onboot)
    if [ ! -f "${SSH_KEY_PATH}" ]; then
        echo "Generating SSH keys..."
        mkdir -p "$(dirname "${SSH_KEY_PATH}")"
        ssh-keygen -f "${SSH_KEY_PATH}" -t ed25519 -N '' -C root@coolify -q
        chown -R 9999:root /data/coolify/ssh
        chmod -R 700 /data/coolify/ssh
    fi
    
    # Add the public key to authorized_keys
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    cat "${SSH_KEY_PATH}.pub" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    
    echo "✓ SSH key activated"
    echo ""
    
    # Give the filesystem a moment to sync
    sleep 2
    
    # Restart Coolify to pick up the changes
    echo "Restarting Coolify containers (this may take 30-60 seconds)..."
    cd /data/coolify/source
    
    # Stop containers first
    docker compose --env-file /data/coolify/source/.env \
      -f /data/coolify/source/docker-compose.yml \
      -f /data/coolify/source/docker-compose.prod.yml \
      down
    
    # Wait a moment before starting back up
    sleep 3
    
    # Start containers
    docker compose --env-file /data/coolify/source/.env \
      -f /data/coolify/source/docker-compose.yml \
      -f /data/coolify/source/docker-compose.prod.yml \
      up -d --pull always --remove-orphans
    
    echo "✓ Coolify containers restarted"
    echo ""
    
    # Mark as configured
    touch /root/.coolify_localhost_configured
    
    # Get IP address
    myip=$(hostname -I | awk '{print$1}')
    
    cat << EOF
================================================================================
                    Localhost Activation Complete!
================================================================================

Your Coolify instance is ready to deploy applications!

Access Coolify at: http://${myip}:8000

Next steps:
  1. Log in to Coolify (or create your admin account if you haven't yet)
  2. The localhost server should now show as connected
  3. Create your first project and start deploying!

For help, visit: https://coolify.io/docs

================================================================================
EOF
else
    echo "Localhost activation skipped."
    echo ""
    echo "You can activate localhost later by running:"
    echo "  /opt/configure-coolify-localhost.sh"
    echo ""
    
    # Mark as configured (user chose to skip)
    touch /root/.coolify_localhost_configured
fi

# Clean up this script from bashrc so it doesn't run again
sed -i '/coolify_localhost_setup.sh/d' /root/.bashrc

echo ""
read -p "Press ENTER to continue..."
clear
