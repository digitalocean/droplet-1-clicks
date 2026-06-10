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

# Install Flask using --break-system-packages for Ubuntu 24.04.
# Gunicorn is installed from apt and runs with system Python, so Flask must be
# importable from the system interpreter too. --ignore-installed avoids pip
# trying to uninstall Debian-owned dependencies such as python3-blinker.
python3 -m pip install --break-system-packages --ignore-installed Flask=="$VERSION"
