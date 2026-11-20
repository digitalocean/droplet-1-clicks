#!/bin/bash
echo "Stopping T3 Code..."
systemctl stop t3code
echo "T3 Code stopped. Caddy left running (use: systemctl stop caddy)."
