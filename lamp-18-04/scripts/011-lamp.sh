#!/bin/sh

chown -R www-data: /etc/apache2
chown -R www-data: /var/log/apache2
chown -R www-data: /var/www
chown -R www-data: /var/www/html

# if applicable, configure lamp to use & wait for a mysql dbaas instance.
if [ -f "/root/.digitalocean_dbaas_credentials" ] && [ "$(sed -n "s/^db_protocol=\"\([^:]*\):.*\"$/\1/p" /root/.digitalocean_dbaas_credentials)" = "mysql" ]; then
  # grab host & port to block until database connection is ready
  host=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  port=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

  # wait for db to become available
  echo -e "\nWaiting for your database to become available (this may take a few minutes)"
  while ! mysqladmin ping -h "$host" -P "$port" --silent; do
      printf .
      sleep 2
  done
  echo -e "\nDatabase available!\n"

  # disable the local MySQL instance
  systemctl stop mysql.service
  systemctl disable mysql.service

  # cleanup
  unset host port
  rm -rf /etc/mysql
fi
