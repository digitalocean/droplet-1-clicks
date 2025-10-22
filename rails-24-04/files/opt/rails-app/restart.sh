#!/bin/bash
cd /opt/rails-app
docker-compose down
docker-compose up -d
echo "Rails application restarted successfully!"