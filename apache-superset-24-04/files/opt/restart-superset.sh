#!/bin/bash
echo "Restarting Apache Superset..."
systemctl restart superset
systemctl restart caddy
sleep 2
if systemctl is-active --quiet superset; then
  echo "Superset restarted successfully."
else
  echo "Failed to restart Superset. Check: journalctl -u superset -xe"
  exit 1
fi
