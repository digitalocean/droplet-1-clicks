#!/bin/bash

echo "=== Twenty CRM Service Status ==="
systemctl status twenty --no-pager || true

echo ""
echo "=== Docker Containers ==="
docker compose -f /opt/twenty/docker-compose.yml ps 2>/dev/null || true

echo ""
echo "=== Caddy Status ==="
systemctl status caddy --no-pager 2>/dev/null || true
