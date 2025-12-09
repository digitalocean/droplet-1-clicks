#!/bin/bash

# Strapi Stop Script
# This script stops the Strapi service

echo "Stopping Strapi..."
systemctl stop strapi

if [ $? -eq 0 ]; then
    echo "✅ Strapi stopped successfully!"
else
    echo "❌ Error: Failed to stop Strapi"
    exit 1
fi
