################################
## PART: configure postfix
##
## vi: syntax=sh expandtab ts=4

sed -e 's/inet_interfaces = all/inet_interfaces = loopback-only/' \
    -i /etc/postfix/main.cf

