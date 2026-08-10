#!/bin/sh

chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

rm -rvf /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/digitalocean \
      /etc/nginx/sites-enabled/digitalocean

rm -rf /var/www/html/index*debian.html

chown -R www-data: /var/www

# Enable fail2ban with sshd jail
systemctl enable fail2ban
systemctl start fail2ban
printf '[sshd]\nenabled = true\nport = 22\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5\n' \
  > /etc/fail2ban/jail.local
systemctl restart fail2ban
