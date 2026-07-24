#!/bin/bash

echo "Starting Plex Media Server..."
systemctl start plex

if /opt/status-plex.sh >/dev/null 2>&1; then
    echo "Plex Media Server started successfully."
    echo ""
    PUBLIC_IP="$(/opt/plex-get-public-ip.sh)"
    if [ -f /opt/plex/.claimed ]; then
        echo "Web interface: https://${PUBLIC_IP}"
        echo "Direct access:  http://${PUBLIC_IP}:32400/web"
    else
        echo "Setup pending:  https://${PUBLIC_IP}"
        echo "Claim with:     /opt/claim-plex.sh <token>"
        echo "Or SSH tunnel, then: /opt/enable-plex-proxy.sh"
    fi
else
    echo "Error: Failed to start Plex Media Server"
    /opt/status-plex.sh || true
    exit 1
fi
