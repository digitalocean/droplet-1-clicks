#!/bin/sh

ufw limit ssh
ufw allow ssh
ufw allow 80/tcp comment 'HTTP (ACME + redirect)'
ufw allow 443/tcp comment 'HTTPS'
# Prometheus is loopback-only; keep 9090 closed to the public
ufw deny 9090/tcp comment 'Prometheus: reach via Caddy on 443'
ufw --force enable
