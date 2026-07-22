#!/bin/bash
echo "Stopping Craft CMS web stack (MySQL left running)..."
systemctl stop caddy php8.3-fpm
echo "Stopped: caddy, php8.3-fpm"
