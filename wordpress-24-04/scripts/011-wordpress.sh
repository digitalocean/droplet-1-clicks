#!/bin/sh

# Download the WordPress bits and cache them on disk
wget -q https://wordpress.org/wordpress-latest.tar.gz -O /tmp/wordpress.tar.gz

# Extract the bits and stage up
mkdir -p /var/www
tar -C /var/www \
    -xvvf /tmp/wordpress.tar.gz

# Update WordPress core to the latest version
cd /var/www/wordpress
wp core update

wget -q https://downloads.wordpress.org/plugin/wp-fail2ban.latest-stable.zip -O /tmp/wp-fail2ban.zip
unzip -q /tmp/wp-fail2ban.zip -d /tmp/

# install the fail2ban bits (plugin itself installed in first-login script)
mkdir -p /etc/fail2ban/filter.d
cp -auv  /tmp/wp-fail2ban/filters.d/* /etc/fail2ban/filter.d
