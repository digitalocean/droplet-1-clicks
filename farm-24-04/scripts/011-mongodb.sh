#!/bin/sh

# Use jammy repo for Ubuntu 24.04 compatibility, as noble is not yet supported
distro="jammy"

# Use MongoDB 7.0 as the latest stable version
mongo_repo_version="7.0"

wget -qO - "https://www.mongodb.org/static/pgp/server-${mongo_repo_version}.asc" | sudo apt-key add -

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${mongo_repo_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb.list


apt-get -qqy update
apt-get -qqy install mongodb-org mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools mongodb-mongosh

# Stop MongoDB from updating to an SSPL version until user decides to
mv -f /etc/apt/sources.list.d/mongodb.list /etc/apt/sources.list.d/mongodb.list.disabled
