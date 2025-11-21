#!/bin/bash

# Strapi Installation Script for DigitalOcean 1-Click
# This script sets up Strapi CMS with Docker on Ubuntu 24.04

set -e

echo "Starting Strapi installation..."

# Configure UFW firewall
echo "Configuring firewall..."
ufw allow 80/tcp
ufw allow 443/tcp
ufw limit ssh/tcp
ufw --force enable

# Enable Docker service
echo "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# Make helper scripts executable
echo "Setting up helper scripts..."
chmod +x /opt/start-strapi.sh
chmod +x /opt/stop-strapi.sh
chmod +x /opt/restart-strapi.sh
chmod +x /opt/update-strapi.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click

# Create strapi directory
mkdir -p /opt/strapi

# Copy Dockerfile and docker-compose.yml to strapi directory
echo "Setting up Strapi configuration..."
cp /opt/Dockerfile /opt/strapi/
cp /opt/docker-compose.yml /opt/strapi/

# Build the Strapi Docker image (this takes several minutes)
echo "Building Strapi Docker image (this may take 5-10 minutes)..."
cd /opt/strapi
docker build -t strapi:local -f Dockerfile .

# Clean up build files in /opt (keep them in /opt/strapi)
rm -f /opt/Dockerfile

echo "Strapi installation completed."
echo "Services will be started automatically on first boot."
