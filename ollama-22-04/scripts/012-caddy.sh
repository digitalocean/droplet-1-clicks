#!/bin/sh

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

sudo mkdir -p /var/log/caddy
sudo chown -R caddy:caddy /var/log/caddy

mv /etc/caddy/Caddyfile /etc/caddy/Caddyfile.template
mv /etc/caddy/Caddyfile-openwebui /etc/caddy/Caddyfile
