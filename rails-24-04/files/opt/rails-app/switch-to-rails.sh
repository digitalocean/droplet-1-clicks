#!/bin/bash

echo "Switching from loading page to Rails application..."

# Stop the loading nginx container
echo "Stopping loading nginx container..."
docker stop nginx-loading 2>/dev/null || true
docker rm nginx-loading 2>/dev/null || true

# Wait for port 80 to be freed
echo "Waiting for port 80 to be available..."
sleep 2

# Check if port 80 is still in use
if ss -tlnp | grep :80; then
    echo "⚠️  Port 80 is still in use after stopping loading container:"
    ss -tlnp | grep :80
    echo "Attempting to kill processes using port 80..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 2
fi

echo "Starting nginx proxy service via docker-compose..."

# Ensure we're in the correct directory
cd /opt/rails-app

# Start the nginx service from docker-compose which will proxy to the Rails app
if docker-compose up -d nginx; then
    # Wait a moment for nginx to start
    sleep 5
    
    # Check if the nginx service is actually running
    if docker-compose ps nginx | grep -q "Up"; then
        echo "✅ Nginx service is running"
        
        # Test if nginx is serving content on port 80
        echo "Testing nginx on port 80..."
        sleep 2  # Give nginx more time to fully start
        
        # Test multiple times in case there's a startup delay
        for i in {1..3}; do
            echo "Test attempt $i:"
            response=$(curl -s http://localhost:80/ | head -5)
            echo "Response preview: $response"
            
            if echo "$response" | grep -q "Rails\|Welcome\|Puma\|Application"; then
                echo "✅ Nginx is serving Rails application on port 80"
                break
            elif echo "$response" | grep -q "loading\|Loading"; then
                echo "⚠️  Still showing loading page on attempt $i"
                if [ $i -eq 3 ]; then
                    echo "❌ Still showing loading page after 3 attempts"
                    echo "Full response:"
                    curl -s http://localhost:80/
                fi
            else
                echo "⚠️  Unexpected response on attempt $i"
            fi
            sleep 2
        done
        
        # Check if nginx can reach the Rails app internally
        echo "Testing nginx connectivity to Rails app..."
        if docker-compose exec -T nginx wget -q --spider http://web:3000/ 2>/dev/null; then
            echo "✅ Nginx can reach Rails app internally"
        else
            echo "⚠️  Nginx cannot reach Rails app internally"
            echo "Checking web service status..."
            docker-compose ps web
            echo "Checking nginx logs..."
            docker-compose logs --tail=10 nginx
        fi
    else
        echo "❌ Nginx service failed to start"
        echo "Docker compose nginx service status:"
        docker-compose ps nginx
        echo "Nginx logs:"
        docker-compose logs nginx
    fi
    
    echo "🌐 Your Rails application should be available at:"
    echo "   - http://$(hostname -I | awk '{print$1}')/ (port 80)"
    echo "   - http://$(hostname -I | awk '{print$1}'):3000/ (direct access)"
    
    # Show the status of all services
    echo "All Docker Compose services status:"
    docker-compose ps
else
    echo "❌ Failed to start nginx proxy service"
    echo "Rails application is still available at port 3000"
    echo "Checking docker-compose status..."
    docker-compose ps
    echo "Checking nginx logs..."
    docker-compose logs nginx
fi