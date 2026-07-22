#!/bin/bash
echo "Restarting Craft CMS stack..."
systemctl restart mysql php8.3-fpm caddy
echo "Restarted: mysql, php8.3-fpm, caddy"
