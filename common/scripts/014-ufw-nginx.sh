#!/bin/sh

ufw limit ssh
ufw allow 'Nginx Full'

ufw --force enable
