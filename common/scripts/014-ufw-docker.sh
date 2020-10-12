#!/bin/sh

sed -e 's|DEFAULT_FORWARD_POLICY=.*|DEFAULT_FORWARD_POLICY="ACCEPT"|g' \
    -i /etc/default/ufw

ufw limit ssh
ufw allow 2375/tcp
ufw allow 2376/tcp

ufw --force enable
