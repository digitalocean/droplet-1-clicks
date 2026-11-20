#!/bin/bash
set -euo pipefail

MIN_RUBY_VERSION="3.4.13"
NGINX_IMAGE="nginx:1.31.9-alpine"
MIN_NGINX_VERSION="1.31.9"

version_ge() {
    local actual="$1"
    local minimum="$2"
    local lower
    lower=$(printf '%s\n%s\n' "$actual" "$minimum" | sort -V | sed -n '1p')
    [ "$lower" = "$minimum" ]
}

verify_ruby_slim_image() {
    local image="ruby:${ruby_version}-slim"
    echo "Verifying Ruby image ${image} (CVE-2026-132825 / GHSA-34m4-m9fh-gqp5)..."
    docker pull "$image"
    local actual
    actual=$(docker run --rm "$image" ruby -e 'print RUBY_VERSION')
    if ! version_ge "$actual" "$MIN_RUBY_VERSION"; then
        echo "ERROR: Ruby ${actual} in ${image} is below minimum ${MIN_RUBY_VERSION}" >&2
        exit 1
    fi
    echo "Ruby ${actual} meets minimum ${MIN_RUBY_VERSION}"
}

verify_nginx_image() {
    echo "Verifying Nginx image ${NGINX_IMAGE} (CVE-2026-123007 / nginx2root)..."
    docker pull "$NGINX_IMAGE"
    local nginx_banner actual
    nginx_banner=$(docker run --rm "$NGINX_IMAGE" nginx -v 2>&1)
    actual=$(printf '%s\n' "$nginx_banner" | sed -n 's/.*nginx\///p' | sed 's/ .*//')
    if [ -z "$actual" ] || ! version_ge "$actual" "$MIN_NGINX_VERSION"; then
        echo "ERROR: Nginx ${actual:-unknown} is below minimum ${MIN_NGINX_VERSION}" >&2
        exit 1
    fi
    echo "Nginx ${actual} meets minimum ${MIN_NGINX_VERSION}"
}

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

verify_ruby_slim_image

# Generate Rails application
echo "Generating Rails application..."
if ! docker run --rm -v "/opt/rails-app":/app -w /app ruby:${ruby_version}-slim bash -c "
  apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs npm git curl libyaml-dev pkg-config &&
  gem install rails -v ${application_version} &&
  rails new . --database=postgresql --skip-git --force &&
  echo 'Rails application generated successfully'
"; then
    echo "ERROR: Failed to generate Rails application"
    exit 1
fi

# Copy custom database.yml configuration
cp /opt/rails-app/database.yml /opt/rails-app/config/database.yml

# Update version placeholders in configuration files
echo "Updating version information in configuration files..."

# Update Dockerfile
sed -i "s/{{RUBY_VERSION}}/${ruby_version}/g" /opt/rails-app/Dockerfile

# Update Gemfile
sed -i "s/{{RUBY_VERSION}}/${ruby_version}/g" /opt/rails-app/Gemfile
sed -i "s/{{RAILS_VERSION}}/${application_version}/g" /opt/rails-app/Gemfile

# Update environment template
sed -i "s/Rails 8\.0\.3/Rails ${application_version}/g" /opt/rails-app/env.template

# Update systemd service
sed -i "s/Rails 8\.0\.3/Rails ${application_version}/g" /etc/systemd/system/rails-app.service

# Update MOTD
sed -i "s/{{RAILS_VERSION}}/${application_version}/g" /etc/update-motd.d/99-one-click
sed -i "s/{{RUBY_VERSION}}/${ruby_version}/g" /etc/update-motd.d/99-one-click

# Update onboot script
sed -i "s/{{RAILS_VERSION}}/${application_version}/g" /var/lib/cloud/scripts/per-instance/001_onboot

# Update welcome page
sed -i "s/{{RAILS_VERSION}}/${application_version}/g" /var/lib/digitalocean/index.html
sed -i "s/{{RUBY_VERSION}}/${ruby_version}/g" /var/lib/digitalocean/index.html

# Update loading page
sed -i "s/{{RAILS_VERSION}}/${application_version}/g" /opt/rails-app/loading.html

# Update Gemfile with correct Rails version
sed -i "s/{{RAILS_VERSION}}/${application_version}/g" /opt/rails-app/Gemfile
sed -i "s/{{RUBY_VERSION}}/${ruby_version}/g" /opt/rails-app/Gemfile

# Copy welcome page and documentation to Rails directory
cp /var/lib/digitalocean/index.html /opt/rails-app/public/
cp /var/lib/digitalocean/README.md /opt/rails-app/

# Update README.md in Rails directory with current versions
sed -i "s/{{application_version}}/${application_version}/g" /opt/rails-app/README.md
sed -i "s/{{ruby_version}}/${ruby_version}/g" /opt/rails-app/README.md

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
# Pre-pull images to speed up first boot (pinned for CVE fixes)
verify_ruby_slim_image
docker pull postgres:15
verify_nginx_image

echo "Docker images pre-pulled for faster startup"

echo "Rails ${application_version} application setup complete!"
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