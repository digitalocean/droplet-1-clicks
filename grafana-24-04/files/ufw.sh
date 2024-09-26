#!/bin/sh

ufw limit ssh
ufw allow ssh
ufw allow 3000/tcp
ufw --force enable