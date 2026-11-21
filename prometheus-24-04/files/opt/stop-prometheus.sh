#!/bin/bash
set -euo pipefail
systemctl stop caddy
systemctl stop prometheus
echo "Prometheus and Caddy stopped."
