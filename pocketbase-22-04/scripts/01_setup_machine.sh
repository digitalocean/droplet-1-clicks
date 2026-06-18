#!/bin/bash 
export DEBIAN_FRONTEND=noninteractive

echo "***********************************"
echo "Setup Instance pocketbase_${PB_VERSION}"
echo "***********************************"

# update system
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install extra libraries.  
sudo DEBIAN_FRONTEND=noninteractive apt install unzip apt-transport-https ca-certificates ufw curl software-properties-common -y

echo "***********************************"
echo "Install PocketBase"
echo "***********************************"

# Install Pocketbase
mkdir /opt/pocketbase && cd /opt/pocketbase
wget https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip
unzip pocketbase_${PB_VERSION}_linux_amd64.zip

echo "***********************************"
echo "Install Caddy"
echo "***********************************"

sudo DEBIAN_FRONTEND=noninteractive apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install caddy -y


echo "***********************************"
echo "Configure UFW"
echo "***********************************"

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8090
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

echo "***********************************"
echo "Copy files into place"
echo "***********************************"

sudo rm /etc/caddy/Caddyfile
sudo cp /var/tmp/Caddyfile /etc/caddy/Caddyfile
sudo cp /var/tmp/99-readme /etc/update-motd.d/99-readme
sudo chmod +x /etc/update-motd.d/99-readme
sudo cp /var/tmp/001-firstrun.sh /var/lib/cloud/scripts/per-instance/001-firstrun.sh
sudo chmod +x /var/lib/cloud/scripts/per-instance/001-firstrun.sh
sudo cp /var/tmp/pocketbase.service /lib/systemd/system/pocketbase.service

