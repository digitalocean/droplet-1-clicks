#!/bin/sh

# Create the django user
useradd --home-dir /home/django \
        --shell /bin/bash \
        --create-home \
        --system \
        django

# Setup the home directory
chown -R django: /home/django
chmod 755 /home/django

if [ -f "/root/.digitalocean_dbaas_credentials" ] && [ "$(sed -n "s/^db_protocol=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)" = "postgresql" ]; then
   # grab host & port to block until database connection is ready
   host=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
   port=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

   # wait for db to become available
   echo -e "\nWaiting for your database to become available (this may take a few minutes)"
   while ! pg_isready -h "$host" -p "$port"; do
       printf .
       sleep 2
   done
   echo -e "\nDatabase available!\n"

   # disable the local Postgresql instance
   systemctl stop postgresql.service
   systemctl disable postgresql.service

   # cleanup
   unset host port
   rm -rf /etc/postgresql
 fi

# Replace with the version of Django you want to install: 4.1.1, etc...
VERSION=${DJANGO_VERSION}

# Install Django
python3 -m pip install Django=="$VERSION"
