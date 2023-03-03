#!/bin/sh

distro="$(lsb_release -s -c)"

wget -qO - "https://www.mongodb.org/static/pgp/server-${mongo_repo_version}.asc" | sudo apt-key add -

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${distro}/mongodb-org/${mongo_repo_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb.list


apt-get -qqy update
apt-get -qqy install mongodb-org=${mongodb_version} mongodb-org-mongos=${mongodb_version} mongodb-org-server=${mongodb_version} mongodb-org-shell=${mongodb_version} mongodb-org-tools=${mongodb_version} mongodb-mongosh

# Stop MongoDB from updating to an SSPL version until user decides to
mv -f /etc/apt/sources.list.d/mongodb.list /etc/apt/sources.list.d/mongodb.list.disabled

#systemctl start mongod
#systemctl enable mongod

# Create mongodb user
#echo 'db.createUser({user: "admin" , pwd: "${admin_mysql_password}" , roles: [{ role: "userAdminAnyDatabase" , db: "admin"}], "mechanisms":["SCRAM-SHA-1"]})' > file.js
#mongosh admin file.js

#mongosh
#use admin
#db.createUser({user: "admin" , pwd: "${admin_mysql_password}" , roles: [{ role: "userAdminAnyDatabase" , db: "admin"}], "mechanisms":["SCRAM-SHA-1"]})
#quit()
#echo "${admin_mysql_password}"