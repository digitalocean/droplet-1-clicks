#!/bin/bash
echo "Stopping OpenHands (Agent Canvas)..."
systemctl stop openhands
echo "OpenHands stopped. Caddy left running (use: systemctl stop caddy)."
