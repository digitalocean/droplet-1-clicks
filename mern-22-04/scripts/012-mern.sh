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

# Create mern folder
mkdir /home/mern
cd /home/mern

# Create express application
npx express-generate server

# Create react application
npx create-react-app client

cd client && npm run build

# Copy sample project
cp /etc/sample-project/src/* /home/mern/client/src

# Delete sample project
rm -r /etc/sample-project

sudo npm install pm2@latest -g --no-optional

su - nodejs -c "pm2 serve /home/mern/client/build 3000 --name \"sample_mern_app\" --spa"
sudo env "PATH=$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u nodejs --hp /home/nodejs
su - nodejs -c "pm2 save"
