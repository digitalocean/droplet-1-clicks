#!/bin/sh
set -e

##############################
## PART: install NodeJS:
##
## vi: syntax=sh expandtab ts=4

# Replace with the branch of Node.js you want to install: 18.x, 20.x, 22.x, lts.x, etc...
VERSION=${NODE_VERSION:-lts.x}
VERSION=${VERSION#node_}

case "$VERSION" in
    lts.x|[0-9]*.x) ;;
    *)
        echo "Unsupported NODE_VERSION: ${NODE_VERSION}. Use values like 20.x, 22.x, 24.x, or lts.x." >&2
        exit 1
        ;;
esac

# Use the NodeSource installation method.
NODESOURCE_SETUP=/tmp/nodesource_setup.sh
curl -fsSL "https://deb.nodesource.com/setup_$VERSION" -o "$NODESOURCE_SETUP"
bash "$NODESOURCE_SETUP"
rm -f "$NODESOURCE_SETUP"

apt-get -qqy update
DEBIAN_FRONTEND=noninteractive apt-get -qqy install nodejs

# npm comes with nodejs, no separate install needed
npm install --global yarn

node -v
npm -v
yarn -v
