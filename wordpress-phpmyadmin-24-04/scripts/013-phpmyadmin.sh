#!/bin/sh
set -e

# Install latest phpMyAdmin from upstream (same pattern as phpmyadmin-24-04).
# No Apache package — WordPress uses Caddy + PHP-FPM.
wget -q -O /tmp/phpMyAdmin-latest-all-languages.tar.gz \
  https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz

mkdir -p /tmp/phpmyadmin-extract /usr/share/phpmyadmin
tar xzf /tmp/phpMyAdmin-latest-all-languages.tar.gz -C /tmp/phpmyadmin-extract
cp -a /tmp/phpmyadmin-extract/phpMyAdmin-*-all-languages/. /usr/share/phpmyadmin/
rm -rf /tmp/phpMyAdmin-latest-all-languages.tar.gz /tmp/phpmyadmin-extract

# Permissions: broad tree first, then lock down tmp (order matters)
chmod -R 755 /usr/share/phpmyadmin
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin/tmp
chmod 700 /usr/share/phpmyadmin/tmp

cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php

# Non-secret defaults only — blowfish_secret is set per Droplet in 001_onboot
cat >> /usr/share/phpmyadmin/config.inc.php <<'EOM'

/* DigitalOcean WordPress + phpMyAdmin 1-Click */
$cfg['TempDir'] = '/usr/share/phpmyadmin/tmp';
$cfg['PmaAbsoluteUri'] = '/phpmyadmin/';
EOM

systemctl enable fail2ban
systemctl start fail2ban

chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click
chmod +x /root/wp_setup.sh
chmod +x /root/wp_setup_domain.sh
