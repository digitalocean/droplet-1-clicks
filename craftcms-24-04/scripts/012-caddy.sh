#!/bin/sh

curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy

chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

chown -R www-data:www-data /var/www

# PHP-FPM socket (ensure after Caddy install)
sed -i 's/^listen = .*/listen = \/run\/php\/php8.3-fpm.sock/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^;listen.owner = www-data/listen.owner = www-data/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^;listen.group = www-data/listen.group = www-data/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^;listen.mode = 0660/listen.mode = 0660/' /etc/php/8.3/fpm/pool.d/www.conf

systemctl enable php8.3-fpm
systemctl start php8.3-fpm

# Pending page until first-login setup (onboot will activate this)
cp /etc/caddy/Caddyfile.setup-pending /etc/caddy/Caddyfile
systemctl enable caddy
systemctl restart caddy
