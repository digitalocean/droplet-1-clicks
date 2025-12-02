#!/bin/bash

echo "Restarting Coolify..."

cd /data/coolify/source

docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml \
  restart

echo "Coolify restarted successfully!"
