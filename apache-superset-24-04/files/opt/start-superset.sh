#!/bin/bash
echo "Starting Apache Superset..."
systemctl start superset
systemctl start caddy
sleep 2
if systemctl is-active --quiet superset; then
  echo "Superset started successfully."
else
  echo "Failed to start Superset. Check: journalctl -u superset -xe"
  exit 1
fi
