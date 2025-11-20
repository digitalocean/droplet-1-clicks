#!/bin/bash

# Strapi Start Script
# This script starts the Strapi service

echo "Starting Strapi..."
systemctl start strapi

if [ $? -eq 0 ]; then
    echo "✅ Strapi started successfully!"
    echo ""
    echo "Access Strapi at: http://$(hostname -I | awk '{print $1}')"
    echo "The admin panel will be available at: http://$(hostname -I | awk '{print $1}')/admin"
else
    echo "❌ Error: Failed to start Strapi"
    exit 1
fi
