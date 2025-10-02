#!/bin/sh

# open port for clients
ufw allow 3000
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# git clone the repo
cd /opt && git clone https://github.com/basecamp/once-campfire.git

# Generate secret key base
YOUR_SECRET_KEY_BASE=$(openssl rand -hex 64)

# Create environment file
cat > /opt/campfire.env << EOF
# Campfire Environment Configuration
# 
# After making changes to this file, restart Campfire with:
#   /opt/restart-campfire.sh

# Rails application secret key for session encryption and security
SECRET_KEY_BASE=$YOUR_SECRET_KEY_BASE

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

chmod +x /opt/restart-campfire.sh
