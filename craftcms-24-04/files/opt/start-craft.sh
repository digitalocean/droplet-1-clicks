#!/bin/bash
echo "Starting Craft CMS stack..."
systemctl start mysql php8.3-fpm caddy
echo "Started: mysql, php8.3-fpm, caddy"
