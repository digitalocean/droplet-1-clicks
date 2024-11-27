#!/bin/sh

# open port for clients
ufw allow 6379
ufw limit ssh/tcp
ufw allow ssh
ufw --force enable

# Get the latest version of valkey
tag_version=$(curl -s "https://api.github.com/repos/valkey-io/valkey/releases/latest" | jq -r '.tag_name')
echo "Latest version of valkey is $tag_version"

#clone valkey project
mkdir /srv
cd /srv
git clone https://github.com/valkey-io/valkey.git
cd valkey
git fetch --tags
git checkout tags/$tag_version

# build valkey
make distclean

# install valkey
make install

REDIS_PORT=6379 \
REDIS_CONFIG_FILE=/srv/valkey/6379.conf \
REDIS_LOG_FILE=/var/log/valkey_6379.log \
REDIS_DATA_DIR=/var/lib/valkey/6379 \
REDIS_EXECUTABLE=`command -v valkey_server` ./utils/install_server.sh