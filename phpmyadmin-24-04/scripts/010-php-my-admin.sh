#!/bin/sh

# Own the bits
chown -R www-data: /var/log/apache2
chown -R www-data: /etc/apache2
chown -R www-data: /var/www

# Manually update phpmyadmin to latest version
wget -O /tmp/phpmyadmin.tar.gz "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"
mv /usr/share/phpmyadmin /usr/share/phpmyadmin.bak
mkdir /usr/share/phpmyadmin

tar xzf /tmp/phpmyadmin.tar.gz -C /tmp
mv /tmp/phpMyAdmin-${phpmyadmin_version}-all-languages/* /usr/share/phpmyadmin

# Use sample config as main config
cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php
# Substitute password placeholder with an actual generated password
sed -i "s+\$cfg\['blowfish_secret'\] = ''; \/\* YOU MUST FILL IN THIS FOR COOKIE AUTH! \*\/+$(echo "\$cfg['blowfish_secret'] = '$(openssl rand -base64 22)';")+g" /usr/share/phpmyadmin/config.inc.php

chmod -Rf 755 /usr/share/phpmyadmin

# Remove auto.cnf so a unique UUID is generated at first boot
rm -f /var/lib/mysql/auto.cnf
