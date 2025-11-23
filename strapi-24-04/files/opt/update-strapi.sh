#!/bin/bash

# Strapi Update Script
# This script updates Strapi to the latest version

echo "Updating Strapi to latest version..."

# Check if Strapi installation exists
if [ ! -d "/opt/strapi" ]; then
    echo "Error: Strapi installation directory not found at /opt/strapi"
    exit 1
fi

# Navigate to Strapi directory
cd /opt/strapi

# Stop existing service
echo "Stopping Strapi service..."
systemctl stop strapi

# Pull latest images
echo "Pulling latest Docker images..."
docker compose pull

# Check if pull was successful
if [ $? -eq 0 ]; then
    echo "Images updated successfully. Restarting Strapi..."
    
    # Remove old containers
    docker compose down
    
    # Start with updated images
    systemctl start strapi
    
    if [ $? -eq 0 ]; then
        echo "✅ Strapi updated and restarted successfully!"
        echo ""
        echo "Access Strapi at: http://$(hostname -I | awk '{print $1}')"
        echo "The admin panel will be available at: http://$(hostname -I | awk '{print $1}')/admin"
    else
        echo "❌ Error: Failed to restart Strapi"
        exit 1
    fi
else
    echo "❌ Error: Failed to pull updated images"
    exit 1
fi

echo "Update process completed."
