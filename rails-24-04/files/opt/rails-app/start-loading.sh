#!/bin/bash

echo "Starting loading page..."

# Check if the loading.html file exists
if [ ! -f /opt/rails-app/loading.html ]; then
    echo "❌ Error: /opt/rails-app/loading.html not found"
    exit 1
fi

# Remove any existing nginx-loading container
docker stop nginx-loading 2>/dev/null || true
docker rm nginx-loading 2>/dev/null || true

# Start nginx with loading configuration that redirects to /loading.html when Rails is not ready
if docker run -d \
    --name nginx-loading \
    -p 80:80 \
    -v /opt/rails-app/nginx-loading.conf:/etc/nginx/nginx.conf:ro \
    -v /opt/rails-app/loading.html:/opt/rails-app/loading.html:ro \
    nginx:alpine; then
    echo "✅ Loading page is now available"
else
    echo "❌ Failed to start loading page"
    exit 1
fi