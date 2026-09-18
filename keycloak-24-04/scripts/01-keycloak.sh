#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

: "${application_version:?application_version must be set}"

# Pin both Keycloak base image tags from Packer application_version (full semver)
sed -i "s|KEYCLOAK_VERSION_PLACEHOLDER|${application_version}|g" /var/digitalocean/Dockerfile

systemctl start docker
systemctl enable docker

# Set up nginx
ln -s /etc/nginx/sites-available/keycloak /etc/nginx/sites-enabled/keycloak
unlink /etc/nginx/sites-enabled/default
service nginx restart
