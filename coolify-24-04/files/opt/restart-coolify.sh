#!/bin/bash

echo "Restarting Coolify..."
# oneshot ExecStop=down + ExecStart=up -d recreates containers even after stop
systemctl restart coolify
echo "Coolify restarted successfully!"
