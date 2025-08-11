#!/bin/bash

droplet_ip=$(hostname -I | awk '{print$1}')

sudo unlink /etc/nginx/sites-enabled/default

# Create the Nginx configuration file for Plausible
# This file will act as a reverse proxy, listening on port 80 and
# passing all requests to the Plausible application running on port 8000.
cat <<EOF | sudo tee /etc/nginx/sites-available/plausible.conf
server {
  listen 80;
  server_name $droplet_ip;

  location / {
    proxy_pass http://localhost:8000;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Host \$http_host;
  }
}
EOF

# Enable the Plausible Nginx site by creating a symbolic link
sudo ln -s /etc/nginx/sites-available/plausible.conf /etc/nginx/sites-enabled/

# Test the Nginx configuration for syntax errors and restart the service
sudo nginx -t && sudo systemctl restart nginx

# echo "Nginx configured and Plausible is accessible at http://$droplet_ip."