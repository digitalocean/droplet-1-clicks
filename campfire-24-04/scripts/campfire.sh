#!/bin/sh

# open port for clients
ufw allow 3000
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# git clone the repo
cd /opt && git clone https://github.com/basecamp/once-campfire.git

# Create environment file (SECRET_KEY_BASE will be generated on first boot)
cat > /opt/campfire.env << EOF
# Campfire Environment Configuration
# 
# After making changes to this file, restart Campfire with:
#   /opt/restart-campfire.sh

# Rails application secret key for session encryption and security
# This will be automatically generated on first boot for security
SECRET_KEY_BASE=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Disable SSL/TLS termination in the container (useful when using a reverse proxy)
DISABLE_SSL=true

# Web Push notification public key (uncomment and set for push notifications)
# VAPID_PUBLIC_KEY=$YOUR_PUBLIC_KEY

# Web Push notification private key (uncomment and set for push notifications)
# VAPID_PRIVATE_KEY=$YOUR_PRIVATE_KEY

# Domain name for automatic SSL certificate generation (uncomment and set your domain)
# TLS_DOMAIN=chat.example.com
EOF

# Build container
cd /opt/once-campfire && docker build -t campfire .

# Get the latest version of campfire
cd /opt/once-campfire && docker run \
  --detach \
  --name campfire \
  --publish 80:80 --publish 443:443 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire

# Create a helper script to restart Campfire with updated environment
cat > /opt/restart-campfire.sh << 'EOF'
#!/bin/bash
echo "Stopping and removing existing Campfire container..."
docker stop campfire 2>/dev/null || true
docker rm campfire 2>/dev/null || true

echo "Starting Campfire with updated environment..."
cd /opt/once-campfire && docker run \
  --detach \
  --name campfire \
  --publish 80:80 --publish 443:443 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire

echo "Campfire restarted successfully!"
EOF

# Create an update script to update Campfire to latest version
cat > /opt/update-campfire.sh << 'EOF'
#!/bin/bash

# Campfire Update Script
# This script pulls the latest Campfire code from GitHub and restarts the service

echo "Updating Campfire to latest version..."

# Check if Campfire installation exists
if [ ! -d "/opt/once-campfire" ]; then
    echo "Error: Campfire installation directory not found at /opt/once-campfire"
    exit 1
fi

# Navigate to Campfire directory
cd /opt/once-campfire

# Pull latest code from GitHub
echo "Pulling latest code from GitHub..."
git pull origin main

# Check if there were any updates
if [ $? -eq 0 ]; then
    echo "Code updated successfully. Rebuilding and restarting Campfire..."
    
    # Stop existing container
    echo "Stopping existing Campfire container..."
    docker stop campfire 2>/dev/null || true
    docker rm campfire 2>/dev/null || true
    
    # Rebuild the image with latest code
    echo "Rebuilding Campfire image..."
    docker build -t campfire .
    
    # Check if build was successful
    if [ $? -eq 0 ]; then
        # Restart Campfire with updated code
        echo "Starting Campfire with updated code..."
        if [ -x "/opt/restart-campfire.sh" ]; then
            /opt/restart-campfire.sh
        else
            # Fallback if restart script doesn't exist
            docker run \
              --detach \
              --name campfire \
              --publish 80:80 --publish 443:443 \
              --restart unless-stopped \
              --volume campfire:/rails/storage \
              --env-file /opt/campfire.env \
              campfire
        fi
        
        if [ $? -eq 0 ]; then
            echo "✅ Campfire updated and restarted successfully!"
        else
            echo "❌ Error: Failed to restart Campfire"
            exit 1
        fi
    else
        echo "❌ Error: Failed to rebuild Campfire image"
        exit 1
    fi
else
    echo "ℹ️  No updates available or update failed."
fi

echo "Update process completed."
EOF

chmod +x /opt/restart-campfire.sh
chmod +x /opt/update-campfire.sh
