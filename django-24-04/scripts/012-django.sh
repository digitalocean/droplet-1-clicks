#!/bin/sh

# Create the django user
useradd --home-dir /home/django \
        --shell /bin/bash \
        --create-home \
        --system \
        django

# Setup the home directory
chown -R django: /home/django
chmod 755 /home/django

# application_version / DJANGO_VERSION come from template.json
VERSION="${DJANGO_VERSION:-$application_version}"

# Install Django using --break-system-packages for Ubuntu 24.04
python3 -m pip install --break-system-packages Django=="$VERSION"
