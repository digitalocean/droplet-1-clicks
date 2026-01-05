#!/bin/sh

#MongoDB doesn't yet publish a "noble" repo, but the jammy (22.04) packages work fine on 24.04.
distro="$(lsb_release -s -c)"

curl -fsSL https://www.mongodb.org/static/pgp/server-${repo_version}.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-${repo_version}.gpg \
   --dearmor --yes

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${repo_version}.gpg ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${repo_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${repo_version}.list
ufw allow 27017/tcp

apt-get -qqy update
sudo DEBIAN_FRONTEND=noninteractive apt-get -qqy install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" mongodb-org=${mongodb_version} mongodb-org-mongos=${mongodb_version} mongodb-org-server=${mongodb_version} mongodb-org-shell=${mongodb_version} mongodb-org-tools=${mongodb_version}

# Stop MongoDB from updating to an SSPL version until user decides to
sudo mv /etc/apt/sources.list.d/mongodb-org-${repo_version}.list /etc/apt/sources.list.d/mongodb-org-${repo_version}.list.disabled
