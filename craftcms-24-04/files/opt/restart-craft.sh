#!/bin/bash
set -euo pipefail

echo "Restarting Craft CMS stack..."
systemctl restart mysql php8.3-fpm caddy
systemctl is-active --quiet mysql php8.3-fpm caddy
echo "Restarted: mysql, php8.3-fpm, caddy"
