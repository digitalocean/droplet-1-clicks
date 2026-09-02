#!/bin/bash
echo "Stopping OpenClaw Gateway..."
systemctl stop openclaw
echo "OpenClaw stopped. Caddy left running (use: systemctl stop caddy)."
