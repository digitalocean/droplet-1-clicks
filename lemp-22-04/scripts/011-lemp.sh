#!/bin/sh

rm -rvf /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/digitalocean \
      /etc/nginx/sites-enabled/digitalocean

rm -rf /var/www/html/index*debian.html

chown -R www-data: /var/www
