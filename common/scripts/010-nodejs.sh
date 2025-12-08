#!/bin/sh

##############################
## PART: install NodeJS:
##
## vi: syntax=sh expandtab ts=4

# Replace with the branch of Node.js you want to install: 18.x, 20.x, 22.x, lts.x, etc...
VERSION=${NODE_VERSION}

# Use the new NodeSource installation method
curl -fsSL "https://deb.nodesource.com/setup_$VERSION" | sudo -E bash -

sudo apt -qqy update
sudo apt -qqy install nodejs

# npm comes with nodejs, no separate install needed
npm install --global yarn

node -v
npm -v
yarn -v
