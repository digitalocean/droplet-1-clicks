#!/bin/sh

ufw limit ssh
ufw allow mysql

ufw --force enable
