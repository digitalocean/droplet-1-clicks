#!/bin/bash
set -e

echo "Updating Craft CMS via Composer..."
cd /var/www/craft
export COMPOSER_ALLOW_SUPERUSER=1
composer update craftcms/cms --with-dependencies --no-interaction
sudo -u www-data php craft migrate/all --interactive=0 || true
sudo -u www-data php craft project-config/apply --interactive=0 || true
chown -R www-data:www-data /var/www/craft
systemctl restart php8.3-fpm caddy
echo "Craft CMS update finished."
