#!/bin/bash

echo "Starting Plex Media Server..."
systemctl start plex

if systemctl is-active --quiet plex; then
    echo "Plex Media Server started successfully."
    echo ""
    echo "Web interface: http://$(hostname -I | awk '{print $1}')"
    echo "Direct access:  http://$(hostname -I | awk '{print $1}'):32400/web"
else
    echo "Error: Failed to start Plex Media Server"
    exit 1
fi
