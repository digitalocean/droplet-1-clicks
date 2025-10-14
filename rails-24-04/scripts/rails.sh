#!/bin/bash

# Configure firewall for Rails application - but don't enable during build
ufw allow 3000
ufw allow 80
ufw allow 443
ufw allow 22/tcp
ufw limit ssh/tcp
# Don't enable UFW during build to avoid SSH lockout
# UFW will be enabled on first boot via systemd service

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Generate credentials
RAILS_SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -hex 16)

# Create environment file from template
cd /opt/rails-app
cp env.template .env

# Populate the environment file
sed -i "s/SECRET_KEY_BASE=/SECRET_KEY_BASE=${RAILS_SECRET_KEY_BASE}/" .env
sed -i "s/POSTGRES_PASSWORD=/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" .env
sed -i "s|DATABASE_URL=|DATABASE_URL=postgresql://rails:${POSTGRES_PASSWORD}@db:5432/rails_production|" .env

# Make scripts executable
chmod +x /opt/rails-app/*.sh

# Ensure onboot script is executable
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Generate Rails application
echo "Generating Rails application..."
if ! docker run --rm -v "/opt/rails-app":/app -w /app ruby:3.4.7-slim bash -c "
  apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs npm git curl libyaml-dev pkg-config &&
  gem install rails -v 8.0.3 &&
  rails new . --database=postgresql --skip-git --force &&
  echo 'Rails application generated successfully'
"; then
    echo "ERROR: Failed to generate Rails application"
    exit 1
fi

# Copy custom database.yml configuration
cp /opt/rails-app/database.yml /opt/rails-app/config/database.yml

# Copy welcome page and documentation to Rails directory
cp /var/lib/digitalocean/index.html /opt/rails-app/public/
cp /var/lib/digitalocean/README.md /opt/rails-app/

# Update Rails configuration for production
# Insert configuration before the final 'end' statement
sed -i '/^end$/i \
\
  # Additional production configuration\
  config.force_ssl = false\
  config.public_file_server.enabled = ENV['"'"'RAILS_SERVE_STATIC_FILES'"'"'].present?\
  config.log_level = :info\
  config.log_tags = [ :request_id ]' /opt/rails-app/config/environments/production.rb

# Set proper ownership for Docker user
chown -R 1000:1000 /opt/rails-app

# Save credentials for user reference
cat > /root/.digitalocean_passwords << EOF
RAILS_SECRET_KEY_BASE=${RAILS_SECRET_KEY_BASE}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF

# Reload systemd but don't enable service yet (first boot will handle startup)
systemctl daemon-reload

# Don't build or start during Packer build - this will be handled by systemd on first boot
# Pre-pull images to speed up first boot
docker pull ruby:3.4.7-slim || true
docker pull postgres:15 || true  
docker pull nginx:alpine || true

echo "Docker images pre-pulled for faster startup"

echo "Rails 8.0.3 application setup complete!"
echo "Application is available at http://your-server-ip"
echo ""
echo "Management commands:"
echo "  Start:   /opt/rails-app/start.sh"
echo "  Stop:    /opt/rails-app/stop.sh"
echo "  Restart: /opt/rails-app/restart.sh"
echo "  Logs:    /opt/rails-app/logs.sh"
echo "  Update:  /opt/rails-app/update.sh"
echo ""
echo "Credentials saved to /root/.digitalocean_passwords"