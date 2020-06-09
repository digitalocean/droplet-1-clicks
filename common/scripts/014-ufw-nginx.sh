#!/bin/sh

################################
## PART: set firewall settings
##
## vi: syntax=sh expandtab ts=4

# protect the droplet
ufw limit ssh
ufw allow 'Nginx Full'
ufw --force enable
