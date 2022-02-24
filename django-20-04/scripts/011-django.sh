#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
        
apt-get -qqy -o Dpkg::Options::=--force-confdef update
apt-get -qqy -o Dpkg::Options::=--force-confdef upgrade

apt-get -qqy -o Dpkg::Options::=--force-confdef install gunicorn nginx postfix postgresql python3 python3-certbot python3-certbot-nginx python3-dev python3-gevent python3-gunicorn python3-netifaces python3-pip python3-psycopg2 python3-setuptools python3-virtualenv super

python3 -m pip install Django
python3 -m django --version

# Create the django user
useradd --home-dir /home/django \
        --shell /bin/bash \
        --create-home \
        --system \
        django

# Setup the home directory
chown -R django: /home/django
