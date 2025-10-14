#!/bin/bash

echo "Switching from loading page to Rails application..."

# Stop the loading nginx container
docker stop nginx-loading 2>/dev/null || true
docker rm nginx-loading 2>/dev/null || true

# Also stop any nginx from docker-compose that might conflict
docker-compose stop nginx 2>/dev/null || true

# Get the Rails app network name
RAILS_NETWORK=$(docker-compose ps -q web | xargs docker inspect --format='{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' | head -1)

if [ -z "$RAILS_NETWORK" ]; then
    echo "Warning: Could not find Rails network, using default"
    RAILS_NETWORK="rails-app_default"
fi

echo "Starting nginx proxy to Rails application..."

# Start nginx proxy that forwards port 80 to Rails app on port 3000
docker run -d \
    --name nginx-proxy \
    --network "$RAILS_NETWORK" \
    -p 80:80 \
    -v /opt/rails-app/nginx.conf:/etc/nginx/nginx.conf:ro \
    nginx:alpine

# Verify the proxy is running
sleep 2
if docker ps | grep -q nginx-proxy; then
    echo "✅ Nginx proxy is running and forwarding port 80 to Rails app"
    echo "🌐 Your Rails application is now available at:"
    echo "   - http://$(hostname -I | awk '{print$1}')/ (port 80)"
    echo "   - http://$(hostname -I | awk '{print$1}'):3000/ (direct access)"
else
    echo "❌ Failed to start nginx proxy"
    echo "Rails application is still available at port 3000"
    docker logs nginx-proxy 2>/dev/null || echo "No proxy logs available"
fi