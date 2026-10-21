#!/bin/sh
set -e

# Own the bits
chown -R www-data: /var/log/apache2
chown -R www-data: /etc/apache2
chown -R www-data: /var/www

# Install phpMyAdmin from upstream at a single pinned version (no Ubuntu package overlay).
wget -q -O /tmp/phpmyadmin.tar.gz \
  "https://files.phpmyadmin.net/phpMyAdmin/${phpmyadmin_version}/phpMyAdmin-${phpmyadmin_version}-all-languages.tar.gz"

rm -rf /usr/share/phpmyadmin
mkdir -p /tmp/phpmyadmin-extract /usr/share/phpmyadmin
tar xzf /tmp/phpmyadmin.tar.gz -C /tmp/phpmyadmin-extract
cp -a /tmp/phpmyadmin-extract/phpMyAdmin-*-all-languages/. /usr/share/phpmyadmin/
rm -rf /tmp/phpmyadmin.tar.gz /tmp/phpmyadmin-extract

chmod -R 755 /usr/share/phpmyadmin
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin/tmp
chmod 700 /usr/share/phpmyadmin/tmp

cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php

# Non-secret defaults only — blowfish_secret is set per Droplet in 001_onboot
cat >> /usr/share/phpmyadmin/config.inc.php <<'EOM'

/* DigitalOcean phpMyAdmin 1-Click */
$cfg['TempDir'] = '/usr/share/phpmyadmin/tmp';
EOM

cat > /etc/apache2/conf-available/phpmyadmin.conf <<'EOF'
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options SymLinksIfOwnerMatch
    DirectoryIndex index.php
    AllowOverride None
    Require all granted
</Directory>
EOF
a2enconf phpmyadmin >/dev/null
systemctl reload apache2

# Certbot from Ubuntu apt is too old for IP-address certificates.
# Install recent Certbot in a dedicated venv for first-boot HTTPS provisioning.
python3 -m venv /opt/certbot-venv
/opt/certbot-venv/bin/pip install --disable-pip-version-check --no-cache-dir "certbot>=5.4,<6"
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click

# Remove auto.cnf so a unique UUID is generated at first boot
rm -f /var/lib/mysql/auto.cnf
