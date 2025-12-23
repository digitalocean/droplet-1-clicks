#!/bin/sh

# Create the mern user
useradd --home-dir /home/mern \
        --shell /bin/bash \
        --create-home \
        --system \
        mern

# Setup the home directory
chown -R mern: /home/mern

# Setup
chown -R mern: /var/www/html

usermod -aG sudo mern

# Create mern folder
mkdir /home/mern
cd /home/mern

# Create express application
npx express-generator server

# Create react application
npx create-react-app client

cd client && npm run build

# Copy sample project
cp /etc/sample-project/src/* /home/mern/client/src

# Delete sample project
rm -r /etc/sample-project
rm /home/mern/client/src/logo.svg

cd /home/mern/client/src && npm run build

sudo npm install pm2@latest -g --no-optional

su - mern -c "pm2 serve /home/mern/client/build 3000 --name \"sample_mern_app\" --spa"
sudo env "PATH=$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u mern --hp /home/mern
su - mern -c "pm2 save"
