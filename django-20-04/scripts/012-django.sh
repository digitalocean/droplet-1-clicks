#!/bin/sh

# Create the django user
useradd --home-dir /home/django \
        --shell /bin/bash \
        --create-home \
        --system \
        django

# Setup the home directory
chown -R django: /home/django
