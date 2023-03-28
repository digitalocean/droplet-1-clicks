#!/bin/sh

# Create the farm user
useradd --home-dir /home/farm \
        --shell /bin/bash \
        --create-home \
        --system \
        farm

# Setup the home directory
chown -R farm: /home/farm

# Setup
chown -R farm: /var/www/html

usermod -aG sudo farm

# Create farm folder
mkdir /home/farm
cd /home/farm

# Create react application
npx create-react-app client

# Copy sample react project
cp /etc/sample-project/client/src/* /home/farm/client/src

# Create server
mkdir server
cd server

# Replace fastapi with the version you want to install: 2.2.3, etc...
VERSION=${FASTAPI_VERSION}

pip install fastapi=="$VERSION" uvicorn[standard] motor gunicorn pipenv

# Copy sample server
cp /etc/sample-project/server/* /home/farm/server

pipenv install -r requirements.txt
ufw allow 8000/tcp

# Delete sample project
rm -r /etc/sample-project
rm /home/farm/client/src/logo.svg

cd /home/farm/client/src && npm run build

sudo npm install pm2@latest -g --no-optional

su - farm -c "cd /home/farm/server && pm2 start \"gunicorn -k uvicorn.workers.UvicornWorker --config /etc/gunicorn.d/gunicorn.py main:app\"  --name \"sample_farm_api\""
su - farm -c "pm2 serve /home/farm/client/build 3000 --name \"sample_farm_app\" --spa"
sudo env "PATH=$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u farm --hp /home/farm
su - farm -c "pm2 save"
