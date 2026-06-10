#!/bin/sh
set -e

distro="$(lsb_release -s -c)"

curl -fsSL "https://www.mongodb.org/static/pgp/server-${mongo_repo_version}.asc" | \
    gpg -o "/usr/share/keyrings/mongodb-server-${mongo_repo_version}.gpg" \
    --dearmor --yes

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${mongo_repo_version}.gpg ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${mongo_repo_version} multiverse" > /etc/apt/sources.list.d/mongodb.list


apt-get -qqy update
DEBIAN_FRONTEND=noninteractive apt-get -qqy install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" mongodb-org=${mongodb_version} mongodb-org-mongos=${mongodb_version} mongodb-org-server=${mongodb_version} mongodb-org-shell=${mongodb_version} mongodb-org-tools=${mongodb_version} mongodb-mongosh

# Stop MongoDB from updating to an SSPL version until user decides to
mv -f /etc/apt/sources.list.d/mongodb.list /etc/apt/sources.list.d/mongodb.list.disabled
