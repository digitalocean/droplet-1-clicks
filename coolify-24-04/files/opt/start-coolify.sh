#!/bin/bash

echo "Starting Coolify..."

cd /data/coolify/source

docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml \
  up -d --pull always --remove-orphans --force-recreate

echo "Coolify started successfully!"
