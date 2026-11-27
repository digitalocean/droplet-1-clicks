#!/bin/sh

ufw limit ssh
ufw allow 'Apache'

ufw --force enable
