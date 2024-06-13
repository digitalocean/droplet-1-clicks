#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

sudo apt -y install postgresql docker.io docker-compose super
systemctl start docker
systemctl enable docker

# Set up nginx
ln -s /etc/nginx/sites-available/keycloak /etc/nginx/sites-enabled/keycloak
unlink /etc/nginx/sites-enabled/default
service nginx restart
