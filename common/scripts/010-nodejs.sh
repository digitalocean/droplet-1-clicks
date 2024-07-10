#!/bin/sh

##############################
## PART: install NodeJS:
##
## vi: syntax=sh expandtab ts=4


# Replace with the branch of Node.js or io.js you want to install: node_6.x, node_8.x, etc...
VERSION=${NODE_VERSION}

curl -fsSL "https://deb.nodesource.com/setup_$VERSION" -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh

# Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt-get -qqy update
sudo apt-get -qqy install nodejs yarn npm

node -v
npm -v
yarn -v