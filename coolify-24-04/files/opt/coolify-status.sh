#!/bin/bash

# Check Coolify status
echo "Checking Coolify status..."

cd /data/coolify/source

docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml \
  ps
