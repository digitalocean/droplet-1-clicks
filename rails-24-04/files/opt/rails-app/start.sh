#!/bin/bash
cd /opt/rails-app
docker-compose up -d
echo "Rails application started successfully!"
echo "Access your application at http://$(curl -s ifconfig.me)"