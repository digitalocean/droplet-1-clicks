#!/bin/bash

echo "Switching from loading page to Rails application..."

# Stop the loading nginx container
docker stop nginx-loading 2>/dev/null || true
docker rm nginx-loading 2>/dev/null || true

# Wait for port 80 to be freed
sleep 2

# Check if port 80 is still in use
if ss -tlnp | grep :80; then
    echo "Port 80 still in use, attempting to free it..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 2
fi

# Ensure we're in the correct directory
cd /opt/rails-app

# Start the nginx service from docker-compose (this will serve Rails on root)
if docker-compose up -d nginx; then
    sleep 3
    
    # Test if nginx is serving Rails content on root
    if curl -f -s http://localhost:80/ | grep -q "Rails\|Welcome\|Puma\|Application"; then
        echo "✅ Rails application is now available at the root URL"
    else
        echo "⚠️  Nginx started but may not be serving Rails content yet"
        # Check if we're still getting redirected to loading.html
        if curl -s -I http://localhost:80/ | grep -q "302\|loading.html"; then
            echo "Still redirecting to loading page - this should resolve shortly"
        fi
    fi
    
    echo "🌐 Your Rails application should be available at:"
    echo "   - http://$(hostname -I | awk '{print$1}')/"
else
    echo "❌ Failed to start nginx proxy service"
    echo "Rails application is still available at port 3000"
fi