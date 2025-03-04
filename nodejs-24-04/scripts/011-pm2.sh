#!/bin/sh

# Create the nodejs user
useradd --home-dir /home/nodejs \
        --shell /bin/bash \
        --create-home \
        --system \
        nodejs

# Setup the home directory
chown -R nodejs: /home/nodejs

# Setup
chown -R nodejs: /var/www/html

usermod -aG sudo nodejs

sudo npm install pm2@latest -g --no-optional

su - nodejs -c "pm2 start /var/www/html/hello.js"
sudo env "PATH=$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u nodejs --hp /home/nodejs
su - nodejs -c "pm2 save"
