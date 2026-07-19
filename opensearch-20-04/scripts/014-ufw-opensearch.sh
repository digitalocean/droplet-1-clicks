#!/bin/sh

ufw limit ssh

ufw allow 9200/tcp
ufw allow 5601/tcp

ufw --force enable
