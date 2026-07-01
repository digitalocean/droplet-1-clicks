#!/bin/sh

ufw limit ssh
ufw allow 27015/tcp
ufw allow 27015/udp
ufw allow 27020/udp

ufw --force enable
