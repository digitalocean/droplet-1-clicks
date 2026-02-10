#!/bin/bash

# OpenClaw Update Script
# This script updates OpenClaw from npm and restarts the service

APP_VERSION="Latest"
if [ -f "/opt/openclaw.env" ]; then
    APP_VERSION_VALUE=$(grep -E '^OPENCLAW_VERSION=' /opt/openclaw.env | tail -n 1 | cut -d'=' -f2-)
    if [ -n "$APP_VERSION_VALUE" ]; then
        APP_VERSION="$APP_VERSION_VALUE"
    fi
fi

echo "Updating OpenClaw (target version: ${APP_VERSION})..."

# Stop the service
echo "Stopping OpenClaw service..."
systemctl stop openclaw

echo "Updating OpenClaw from npm..."

if [ "$APP_VERSION" = "Latest" ]; then
    npm update -g openclaw
else
    npm install -g openclaw@${APP_VERSION}
fi

if [ $? -eq 0 ]; then
    echo "OpenClaw updated successfully."

    # Update version in env file
    INSTALLED_VERSION=$(npm list -g openclaw --depth=0 | grep openclaw@ | sed 's/.*openclaw@//' | sed 's/ .*//')
    if [ -n "$INSTALLED_VERSION" ]; then
        sed -i "s/^OPENCLAW_VERSION=.*/OPENCLAW_VERSION=v${INSTALLED_VERSION}/" /opt/openclaw.env
    fi

    # Restart OpenClaw
    echo "Starting OpenClaw with updated version..."
    systemctl start openclaw

    if [ $? -eq 0 ]; then
        echo "✅ OpenClaw updated and restarted successfully!"
        echo "Version: ${INSTALLED_VERSION}"
    else
        echo "❌ Error: Failed to restart OpenClaw"
        exit 1
    fi
else
    echo "❌ Error: Failed to update OpenClaw"
    systemctl start openclaw
    exit 1
fi

echo "Update process completed."