#!/bin/sh

# Create the mean user
useradd --home-dir /home/mean \
        --shell /bin/bash \
        --create-home \
        --system \
        mean

# Setup the home directory
chown -R mean: /home/mean

# Setup
chown -R mean: /var/www/html

usermod -aG sudo mean

# Create mean folder
mkdir /home/mean
cd /home/mean

# Create express application
npx express-generator server

# Create angular application
npx @angular/cli new client --routing=true --style=css --skip-git

# Copy sample project
cp /etc/sample-project/src/favicon.ico /home/mean/client/src
cp /etc/sample-project/src/app.component.html /home/mean/client/src/app

# Delete sample project
rm -r /etc/sample-project

cd /home/mean/client && npx ng build client

sudo npm install pm2@latest -g --no-optional

su - mean -c "pm2 serve /home/mean/client/dist/client 3000 --name \"sample_mean_app\" --spa"
sudo env "PATH=$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u mean --hp /home/mean
su - mean -c "pm2 save"
