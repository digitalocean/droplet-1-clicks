#!/bin/sh

# Own the bits
chown -R www-data: /var/log/apache2
chown -R www-data: /etc/apache2
chown -R www-data: /var/www

# Manually update phpmyadmin to latest version
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar xvf phpMyAdmin-latest-all-languages.tar.gz
sudo mkdir -p /usr/share/phpmyadmin
sudo mv phpMyAdmin-*-all-languages/* /usr/share/phpmyadmin/

# Set up Apache/Nginx alias (Apache example)
echo 'Include /etc/phpmyadmin/apache.conf' | sudo tee /etc/apache2/conf-enabled/phpmyadmin.conf
sudo systemctl reload apache2

tar xzf /tmp/phpmyadmin.tar.gz -C /tmp
mv /tmp/phpMyAdmin-${phpmyadmin_version}-all-languages/* /usr/share/phpmyadmin

# Use sample config as main config
cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php
# Substitute password placeholder with an actual generated password
sed -i "s+\$cfg\['blowfish_secret'\] = ''; \/\* YOU MUST FILL IN THIS FOR COOKIE AUTH! \*\/+$(echo "\$cfg['blowfish_secret'] = '$(openssl rand -base64 22)';")+g" /usr/share/phpmyadmin/config.inc.php

chmod -Rf 755 /usr/share/phpmyadmin

# Certbot from Ubuntu apt is too old for IP-address certificates.
# Install recent Certbot in a dedicated venv for first-boot HTTPS provisioning.
python3 -m venv /opt/certbot-venv
/opt/certbot-venv/bin/pip install --disable-pip-version-check --no-cache-dir "certbot>=5.4,<6"
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click

# Remove auto.cnf so a unique UUID is generated at first boot
rm -f /var/lib/mysql/auto.cnf
