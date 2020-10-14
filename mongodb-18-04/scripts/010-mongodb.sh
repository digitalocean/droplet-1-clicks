#!/bin/sh

distro="$(lsb_release -s -c)"

wget -qO - "https://www.mongodb.org/static/pgp/server-${repo_version}.asc" | sudo apt-key add -

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${repo_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb.list


apt-get -qqy update
apt-get -qqy install mongodb-org=${mongodb_version} mongodb-org-mongos=${mongodb_version} mongodb-org-server=${mongodb_version} mongodb-org-shell=${mongodb_version} mongodb-org-tools=${mongodb_version}

# Stop MongoDB from updating to an SSPL version until user decides to
mv -f /etc/apt/sources.list.d/mongodb.list /etc/apt/sources.list.d/mongodb.list.disabled
