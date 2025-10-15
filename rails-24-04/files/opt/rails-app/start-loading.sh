#!/bin/bash

echo "Starting loading page service..."

# Check if the loading.html file exists
if [ ! -f /opt/rails-app/loading.html ]; then
    echo "❌ Error: /opt/rails-app/loading.html not found"
    ls -la /opt/rails-app/
    exit 1
fi

echo "✅ Loading page file exists"

# Remove any existing nginx-loading container
docker stop nginx-loading 2>/dev/null || true
docker rm nginx-loading 2>/dev/null || true

# Check if port 80 is already in use
if ss -tlnp | grep :80; then
    echo "⚠️  Port 80 is already in use:"
    ss -tlnp | grep :80
fi

# Start nginx with loading configuration on port 80
echo "Starting nginx container..."
if docker run -d \
    --name nginx-loading \
    -p 80:80 \
    -v /opt/rails-app/loading.html:/usr/share/nginx/html/index.html:ro \
    nginx:alpine; then
    echo "Loading page container started successfully"
    echo "Loading page is now available at http://$(hostname -I | awk '{print$1}')"
    
    # Verify the container is running
    sleep 2
    if docker ps | grep -q nginx-loading; then
        echo "✅ nginx-loading container is running"
        docker ps | grep nginx-loading
    else
        echo "❌ nginx-loading container failed to start"
        docker logs nginx-loading 2>/dev/null || echo "No logs available"
    fi
else
    echo "❌ Failed to start nginx-loading container"
    exit 1
fi