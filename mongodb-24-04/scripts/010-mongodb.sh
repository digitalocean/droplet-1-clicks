#!/bin/sh

#MongoDB doesn’t yet publish a “noble” repo, but the jammy (22.04) packages work fine on 24.04.
#distro="$(lsb_release -s -c)"
distro="jammy"

wget -qO - "https://www.mongodb.org/static/pgp/server-${repo_version}.asc" | sudo apt-key add -

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${repo_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb.list

ufw allow 27017/tcp

apt-get -qqy update
apt-get -qqy install mongodb-org=${mongodb_version} mongodb-org-mongos=${mongodb_version} mongodb-org-server=${mongodb_version} mongodb-org-shell=${mongodb_version} mongodb-org-tools=${mongodb_version}

# Stop MongoDB from updating to an SSPL version until user decides to
mv -f /etc/apt/sources.list.d/mongodb.list /etc/apt/sources.list.d/mongodb.list.disabled
