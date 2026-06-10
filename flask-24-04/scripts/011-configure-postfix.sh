#!/bin/sh

sed -e 's/inet_interfaces = all/inet_interfaces = loopback-only/' \
    -i /etc/postfix/main.cf
