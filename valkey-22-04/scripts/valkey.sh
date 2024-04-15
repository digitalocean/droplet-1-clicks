#!/bin/sh

# open port for clients
ufw allow 6379
ufw allow ssh
ufw --force enable

# make directory
mkdir /var/lib/digitalocean

#clone valkey project
mkdir /srv
cd /srv
git clone --depth 1 https://github.com/valkey-io/valkey.git

# build valkey
cd /srv/valkey
make distclean

# install valkey
make install

REDIS_PORT=6379 \
REDIS_CONFIG_FILE=/srv/valkey/6379.conf \
REDIS_LOG_FILE=/var/log/valkey_6379.log \
REDIS_DATA_DIR=/var/lib/valkey/6379 \
REDIS_EXECUTABLE=`command -v valkey_server` ./utils/install_server.sh