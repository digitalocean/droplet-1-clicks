#!/bin/bash

# Strapi Restart Script
# This script restarts the Strapi service with updated environment

echo "Stopping Strapi..."
systemctl stop strapi

echo "Starting Strapi with updated configuration..."
systemctl start strapi

if [ $? -eq 0 ]; then
    echo "✅ Strapi restarted successfully!"
    echo ""
    echo "Access Strapi at: http://$(hostname -I | awk '{print $1}')"
    echo "The admin panel will be available at: http://$(hostname -I | awk '{print $1}')/admin"
else
    echo "❌ Error: Failed to restart Strapi"
    exit 1
fi
