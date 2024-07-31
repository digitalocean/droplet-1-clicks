################################
## PART: configure Ghost
##
## vi: syntax=sh expandtab ts=4

GHOST_CLI_VERSION="${ghost_cli_version}"
VERSION=${NODE_VERSION}

curl -fsSL "https://deb.nodesource.com/setup_$VERSION" -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh

# Run update and install
sudo apt-get update
sudo apt-get install nodejs -y

useradd --home-dir /home/ghost-mgr \
        --shell /bin/bash \
        --create-home \
        --comment 'Ghost Management User' \
        --groups sudo \
        ghost-mgr

cat > /etc/sudoers.d/99-do-ghost <<EOM
# Created by DigitalOcean 1-Click for Ghost CLI management.
ghost-mgr ALL=(ALL) NOPASSWD:ALL
EOM

chmod 755 /var/www
mkdir -p /var/www/ghost
chown -R ghost-mgr: /var/www/ghost
chmod 775 /var/www/ghost

# Install Ghost-CLI
su ghost-mgr -c "bash -x <<EOM
sudo npm i -g ghost-cli@${GHOST_CLI_VERSION} > /tmp/npm.log || { tail -n 100 /tmp/npm.log; exit 1; }
EOM
"
