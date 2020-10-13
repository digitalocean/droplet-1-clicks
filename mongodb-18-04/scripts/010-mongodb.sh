#!/bin/sh

distro="$(lsb_release -s -c)"

wget -qO - "https://www.mongodb.org/static/pgp/server-${mongodb_version}.asc" | sudo apt-key add -

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${mongodb_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb.list


apt-get -qqy update
apt-get -qqy install mongodb-org mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools

# Stop MongoDB from updating to an SSPL version until user decides to
mv -f /etc/apt/sources.list.d/mongodb.list /etc/apt/sources.list.d/mongodb.list.disabled
