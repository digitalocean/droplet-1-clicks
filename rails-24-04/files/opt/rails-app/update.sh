#!/bin/bash
cd /opt/rails-app
echo "Updating Rails application..."
docker-compose down
docker-compose build --no-cache
docker-compose up -d
echo "Rails application updated and restarted!"