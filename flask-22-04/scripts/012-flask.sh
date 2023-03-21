#!/bin/sh

# Create the flask user
useradd --home-dir /home/flask \
        --shell /bin/bash \
        --create-home \
        --system \
        flask

# Setup the home directory
chown -R flask: /home/flask
chmod 755 /home/flask

# Replace with the version of Flask you want to install: 2.2.3, etc...
VERSION=${FLASK_VERSION}

# Install Flask
python3 -m pip install flask=="$VERSION"
