#!/bin/bash

# Check Coolify status (systemd + containers)
echo "Checking Coolify status..."
echo ""
echo "systemd: $(systemctl is-active coolify 2>/dev/null || echo unknown)"
systemctl --no-pager --full status coolify 2>/dev/null | head -n 15 || true
echo ""
echo "Containers:"
cd /data/coolify/source
docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml \
  ps
