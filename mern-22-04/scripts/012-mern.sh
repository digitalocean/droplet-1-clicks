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

cd /home/

# Create express application
npx express-generate mern/server

# Create react application inside of express application
npx create-react-app mern/client

# Copy sample project
cp /tmp/src/* /home/mern/client/src

# Delete sample project
rm -r /tmp

sudo npm install pm2@latest -g --no-optional

su - nodejs -c "pm2 serve /home/mern/client/src 3000 --name \"sample_mern_app\" --spa"
sudo env "PATH=$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u nodejs --hp /home/nodejs
su - nodejs -c "pm2 save"
