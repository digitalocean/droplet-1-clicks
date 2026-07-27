#!/bin/bash
set -euo pipefail

echo "Starting Craft CMS stack..."
systemctl start mysql php8.3-fpm caddy
systemctl is-active --quiet mysql php8.3-fpm caddy
echo "Started: mysql, php8.3-fpm, caddy"
