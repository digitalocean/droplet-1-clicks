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

# Replace with the version of Django you want to install: 4.1.1, etc...
VERSION=${DJANGO_VERSION}

# Install Django using --break-system-packages for Ubuntu 24.04
python3 -m pip install --break-system-packages Django=="$VERSION"
