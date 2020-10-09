#!/bin/sh

chown -R www-data: /var/log/apache2
chown -R www-data: /etc/apache2
chown -R www-data: /var/www

# Enable re-write
(cd /etc/apache2/mods-enabled/ &&
 ln -vs ../mods-available/rewrite.load . )
