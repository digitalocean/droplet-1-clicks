#!/bin/sh

chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

rm -rvf /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/digitalocean \
      /etc/nginx/sites-enabled/digitalocean

rm -rf /var/www/html/index*debian.html

chown -R www-data: /var/www

systemctl enable fail2ban
systemctl start fail2ban
