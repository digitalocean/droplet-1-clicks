#!/bin/bash

# View Coolify logs
echo "Viewing Coolify logs (press Ctrl+C to exit)..."

cd /data/coolify/source

docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml \
  logs -f
