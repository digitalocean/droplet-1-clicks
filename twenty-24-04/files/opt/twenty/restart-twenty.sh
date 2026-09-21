#!/bin/bash
set -e

echo "Restarting Twenty CRM..."
systemctl restart twenty

if systemctl is-active --quiet twenty; then
    echo "Twenty CRM restarted successfully."
else
    echo "Failed to restart Twenty CRM. Check: systemctl status twenty"
    exit 1
fi
