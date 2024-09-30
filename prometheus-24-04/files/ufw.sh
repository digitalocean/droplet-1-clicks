#!/bin/sh

ufw limit ssh
ufw allow ssh
ufw allow 9090/tcp
ufw --force enable