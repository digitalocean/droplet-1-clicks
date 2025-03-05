#!/bin/sh

##############################
## PART: install NodeJS:
##
## vi: syntax=sh expandtab ts=4

# Replace with the branch of Node.js or io.js you want to install: node_6.x, node_8.x, etc...
VERSION=${NODE_VERSION}

curl -fsSL "https://deb.nodesource.com/setup_$VERSION" -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh

sudo apt -qqy update
sudo apt -qqy install nodejs 
sudo apt -qqy npm

npm install --global yarn

node -v
npm -v
yarn -v
