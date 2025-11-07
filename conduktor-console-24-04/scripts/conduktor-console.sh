#!/bin/sh

# Get the application version from environment variable (set by Packer)
CONDUKTOR_VERSION="${application_version:-1.39.0}"

# Configure firewall
ufw allow 8080
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Ensure Docker is enabled and started
systemctl enable docker
systemctl start docker

# Create Conduktor directory structure
mkdir -p /opt/conduktor
cd /opt/conduktor

# Update docker-compose.yml with the correct version
sed -i "s/conduktor\/conduktor-console:[0-9.]\+/conduktor\/conduktor-console:${CONDUKTOR_VERSION}/g" /opt/conduktor/docker-compose.yml
sed -i "s/conduktor\/conduktor-console-cortex:[0-9.]\+/conduktor\/conduktor-console-cortex:${CONDUKTOR_VERSION}/g" /opt/conduktor/docker-compose.yml

# Set proper permissions for docker-compose.yml and helper scripts
chmod 644 /opt/conduktor/docker-compose.yml
chmod +x /opt/conduktor/*.sh

# Create environment file with placeholders (actual secrets will be generated on first boot)
cat > /opt/conduktor/conduktor.env << 'EOF'
# Conduktor Console Environment Configuration
#
# After making changes to this file, restart Conduktor Console with:
#   /opt/conduktor/restart-conduktor.sh

# PostgreSQL Database Configuration
POSTGRES_DB=conduktor-console
POSTGRES_USER=conduktor
POSTGRES_PASSWORD=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Conduktor Console Configuration
CDK_ORGANIZATION_NAME=my-organization
CDK_DATABASE_URL=postgresql://conduktor:PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT@postgresql:5432/conduktor-console
CDK_MONITORING_CORTEX-URL=http://conduktor-monitoring:9009/
CDK_MONITORING_ALERT-MANAGER-URL=http://conduktor-monitoring:9010/
CDK_MONITORING_CALLBACK-URL=http://conduktor-console:8080/monitoring/api/
CDK_MONITORING_NOTIFICATIONS-CALLBACK-URL=http://localhost:8080

# Admin User - Default credentials (CHANGE THESE!)
# Generate a secure admin password on first boot
CDK_ADMIN_EMAIL=admin@conduktor.local
CDK_ADMIN_PASSWORD=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Cortex Monitoring Configuration
CDK_CONSOLE-URL=http://conduktor-console:8080
EOF

# Create a helper script to restart Conduktor Console with updated environment
cat > /opt/conduktor/restart-conduktor.sh << 'RESTART_EOF'
#!/bin/bash
echo "Restarting Conduktor Console..."
cd /opt/conduktor

# Stop all services
docker compose --env-file conduktor.env down

# Start all services with updated environment
docker compose --env-file conduktor.env up -d

echo "Conduktor Console restarted successfully!"
echo ""
echo "Console will be available at http://$(hostname -I | awk '{print$1}'):8080"
echo "Default admin credentials are in /opt/conduktor/conduktor.env"
RESTART_EOF

# Create a start script
cat > /opt/conduktor/start-conduktor.sh << 'START_EOF'
#!/bin/bash
echo "Starting Conduktor Console..."
cd /opt/conduktor
docker compose --env-file conduktor.env up -d
echo "Conduktor Console started successfully!"
echo ""
echo "Console is available at http://$(hostname -I | awk '{print$1}'):8080"
echo "Default admin credentials are in /opt/conduktor/conduktor.env"
START_EOF

# Create a stop script
cat > /opt/conduktor/stop-conduktor.sh << 'STOP_EOF'
#!/bin/bash
echo "Stopping Conduktor Console..."
cd /opt/conduktor
docker compose --env-file conduktor.env down
echo "Conduktor Console stopped successfully!"
STOP_EOF

# Create an update script
cat > /opt/conduktor/update-conduktor.sh << 'UPDATE_EOF'
#!/bin/bash

# Conduktor Console Update Script
# This script pulls the latest Conduktor Console images and restarts the services

echo "Updating Conduktor Console to latest version..."

# Check if Conduktor installation exists
if [ ! -d "/opt/conduktor" ]; then
    echo "Error: Conduktor installation directory not found at /opt/conduktor"
    exit 1
fi

# Navigate to Conduktor directory
cd /opt/conduktor

# Pull latest images
echo "Pulling latest Docker images..."
docker compose --env-file conduktor.env pull

# Check if pull was successful
if [ $? -eq 0 ]; then
    echo "Images updated successfully. Restarting Conduktor Console..."
    
    # Restart services with new images
    docker compose --env-file conduktor.env down
    docker compose --env-file conduktor.env up -d
    
    if [ $? -eq 0 ]; then
        echo "✅ Conduktor Console updated and restarted successfully!"
        echo ""
        echo "Console is available at http://$(hostname -I | awk '{print$1}'):8080"
    else
        echo "❌ Error: Failed to restart Conduktor Console"
        exit 1
    fi
else
    echo "❌ Error: Failed to pull latest images"
    exit 1
fi

echo "Update process completed."
UPDATE_EOF

# Create a logs script
cat > /opt/conduktor/logs-conduktor.sh << 'LOGS_EOF'
#!/bin/bash
echo "Showing Conduktor Console logs (press Ctrl+C to exit)..."
cd /opt/conduktor
docker compose --env-file conduktor.env logs -f
LOGS_EOF

chmod +x /opt/conduktor/restart-conduktor.sh
chmod +x /opt/conduktor/start-conduktor.sh
chmod +x /opt/conduktor/stop-conduktor.sh
chmod +x /opt/conduktor/update-conduktor.sh
chmod +x /opt/conduktor/logs-conduktor.sh

echo "Conduktor Console installation completed."
echo "Services will be started on first boot via the onboot script."
