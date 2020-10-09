#!/bin/sh

# Download the WordPress bits and cache them on disk
wget "https://wordpress.org/wordpress-${application_version}.tar.gz" \
     -O /tmp/wordpress.tar.gz

# Extract the bits and stage up
mkdir -p /var/www
tar -C /var/www \
    -xvvf /tmp/wordpress.tar.gz

wpfail2ban="wp-fail2ban.${fail2ban_version}.zip"
wget https://downloads.wordpress.org/plugin/${wpfail2ban} -O /tmp/wp-fail2ban.zip
unzip /tmp/wp-fail2ban.zip -d /tmp/

# install the fail2ban bits (plugin itself installed in first-login script)
mkdir -p /etc/fail2ban/filter.d
cp -auv  /tmp/wp-fail2ban/filters.d/* /etc/fail2ban/filter.d
