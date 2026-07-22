#!/bin/bash
set -euo pipefail

# Configure PHP for FPM / CLI — sized for Craft CMS
sed -e "s|memory_limit.*|memory_limit = 512M|g" \
    -e "s|upload_max_filesize.*|upload_max_filesize = 64M|g" \
    -e "s|post_max_size.*|post_max_size = 64M|g" \
    -e "s|max_execution_time.*|max_execution_time = 300|g" \
    -e "s|max_input_vars.*|max_input_vars = 5000|g" \
    -i /etc/php/8.3/fpm/php.ini

sed -e "s|memory_limit.*|memory_limit = 512M|g" \
    -e "s|upload_max_filesize.*|upload_max_filesize = 64M|g" \
    -e "s|post_max_size.*|post_max_size = 64M|g" \
    -e "s|max_execution_time.*|max_execution_time = 300|g" \
    -e "s|max_input_vars.*|max_input_vars = 5000|g" \
    -i /etc/php/8.3/cli/php.ini

sed -i 's/^listen = .*/listen = \/run\/php\/php8.3-fpm.sock/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^;listen.owner = www-data/listen.owner = www-data/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^;listen.group = www-data/listen.group = www-data/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php/8.3/fpm/pool.d/www.conf

# Install Craft CMS into /var/www/craft
# --no-install/--no-scripts: skip post-create hooks that need a database.
if [ -z "${CRAFT_VERSION:-}" ]; then
  echo "ERROR: CRAFT_VERSION is empty; set application_version in template.json" >&2
  exit 1
fi

mkdir -p /var/www
rm -rf /var/www/craft
export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_HOME=/root/.composer

# Starter package versions ≠ CMS versions (e.g. craftcms/craft has no 5.10.11).
# Pin the Craft 5 starter, then pin craftcms/cms to application_version.
composer create-project "craftcms/craft:^5.0" /var/www/craft \
  --no-interaction \
  --prefer-dist \
  --no-install \
  --no-scripts

cd /var/www/craft

if [ -f composer.json.default ]; then
  rm -f composer.json
  mv composer.json.default composer.json
fi

composer install --no-interaction --prefer-dist --optimize-autoloader

composer require "craftcms/cms:${CRAFT_VERSION}" \
  --no-interaction \
  --update-with-dependencies \
  --prefer-dist

cat > /var/www/craft/.env <<'EOF'
# DigitalOcean Craft CMS 1-Click
# https://craftcms.com/docs/5.x/configure.html

CRAFT_APP_ID=
CRAFT_ENVIRONMENT=production

CRAFT_DB_DRIVER=mysql
CRAFT_DB_SERVER=127.0.0.1
CRAFT_DB_PORT=3306
CRAFT_DB_DATABASE=craftcms
CRAFT_DB_USER=craft
CRAFT_DB_PASSWORD=
CRAFT_DB_SCHEMA=
CRAFT_DB_TABLE_PREFIX=

CRAFT_SECURITY_KEY=
CRAFT_DEV_MODE=false
CRAFT_ALLOW_ADMIN_CHANGES=true
CRAFT_DISALLOW_ROBOTS=false
EOF

chown -R www-data:www-data /var/www/craft
chmod -R u+rwX,g+rwX /var/www/craft/storage /var/www/craft/web/cpresources 2>/dev/null || true
chmod +x /var/www/craft/craft
chmod +x /root/craft_setup.sh
chmod +x /root/craft_setup_domain.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click
chmod +x /opt/start-craft.sh /opt/stop-craft.sh /opt/restart-craft.sh /opt/update-craft.sh /opt/status-craft.sh

# Enable fail2ban (sshd jail ships with the package)
systemctl enable fail2ban
systemctl restart fail2ban || true

systemctl enable php8.3-fpm mysql
systemctl restart php8.3-fpm
