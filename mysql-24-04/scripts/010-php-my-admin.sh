#!/bin/sh

# Own the bits
chown -R www-data: /var/log/apache2
chown -R www-data: /etc/apache2
chown -R www-data: /var/www

# Manually update phpmyadmin to latest version
wget -O /tmp/phpmyadmin.tar.gz "https://files.phpmyadmin.net/phpMyAdmin/${phpmyadmin_version}/phpMyAdmin-${phpmyadmin_version}-all-languages.tar.gz"
mv /usr/share/phpmyadmin /usr/share/phpmyadmin.bak
mkdir /usr/share/phpmyadmin

tar xzf /tmp/phpmyadmin.tar.gz -C /tmp
mv /tmp/phpMyAdmin-${phpmyadmin_version}-all-languages/* /usr/share/phpmyadmin
chmod -Rf 755 /usr/share/phpmyadmin

# Remove auto.cnf so a unique UUID is generated at first boot
rm -f /var/lib/mysql/auto.cnf

mkdir /usr/share/phpmyadmin/tmp/
chown -R www-data /usr/share/phpmyadmin/tmp/

cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php
sed -i "s|\(\$cfg\['blowfish_secret'\] = '\)[^']*';|\1$(openssl rand -hex 16)';|" /usr/share/phpmyadmin/config.inc.php
