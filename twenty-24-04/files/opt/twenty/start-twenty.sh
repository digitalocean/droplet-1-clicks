#!/bin/bash
set -e

echo "Starting Twenty CRM..."
systemctl start twenty

if systemctl is-active --quiet twenty; then
    echo "Twenty CRM started successfully."
    echo "Access at: https://$(curl -fsS --retry 3 --max-time 2 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || hostname -I | awk '{print $1}')"
else
    echo "Failed to start Twenty CRM. Check: systemctl status twenty"
    exit 1
fi
