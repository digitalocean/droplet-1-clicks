#!/bin/sh

ufw limit ssh
ufw allow 15672/tcp
ufw allow 5672/tcp

ufw --force enable
