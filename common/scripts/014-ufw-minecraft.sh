#!/bin/sh

ufw limit ssh
ufw allow 25565/tcp

ufw --force enable
