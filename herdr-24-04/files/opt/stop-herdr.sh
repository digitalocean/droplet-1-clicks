#!/bin/bash
set -euo pipefail
systemctl stop herdr.service
systemctl is-active herdr.service || true
echo "Herdr server stopped."
