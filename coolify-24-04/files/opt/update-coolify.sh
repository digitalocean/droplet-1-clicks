#!/bin/bash

# Coolify Update Script
# This script updates Coolify to the latest version

echo "Updating Coolify to the latest version..."

# Navigate to Coolify source directory
cd /data/coolify/source

# Download the latest upgrade script
curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh -o /data/coolify/source/upgrade.sh
chmod +x /data/coolify/source/upgrade.sh

# Run the upgrade script
bash /data/coolify/source/upgrade.sh

echo "Coolify updated successfully!"
