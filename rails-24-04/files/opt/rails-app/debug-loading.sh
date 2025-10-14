#!/bin/bash

echo "=== Debugging nginx-loading container ==="

echo "1. Checking if Docker is running..."
docker --version
docker info | grep -E "Server Version|Running|Paused|Stopped" || echo "Docker info failed"

echo -e "\n2. Checking current containers..."
docker ps -a

echo -e "\n3. Checking if loading.html exists..."
ls -la /opt/rails-app/loading.html

echo -e "\n4. Checking port 80 usage..."
netstat -tlnp | grep :80 || echo "Port 80 is available"

echo -e "\n5. Trying to start nginx-loading manually..."
docker stop nginx-loading 2>/dev/null
docker rm nginx-loading 2>/dev/null

docker run -d \
    --name nginx-loading \
    -p 80:80 \
    -v /opt/rails-app/loading.html:/usr/share/nginx/html/index.html:ro \
    nginx:alpine

echo -e "\n6. Checking if container started..."
sleep 2
docker ps | grep nginx-loading || echo "Container not running"

echo -e "\n7. Checking container logs..."
docker logs nginx-loading 2>/dev/null || echo "No logs available"

echo -e "\n8. Testing local connection..."
curl -s http://localhost/ | head -20 || echo "Failed to connect to localhost"

echo -e "\n9. Testing external IP..."
external_ip=$(hostname -I | awk '{print$1}')
echo "External IP: $external_ip"
curl -s http://$external_ip/ | head -20 || echo "Failed to connect to external IP"

echo -e "\n=== Debug complete ==="