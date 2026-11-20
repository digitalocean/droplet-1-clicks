#!/bin/sh
set -eu

# open port for clients
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

cat > /opt/ensure-campfire-ruby.sh << 'ENSURE_EOF'
#!/bin/sh
set -eu

MIN_RUBY_VERSION=4.0.10
ONCE_CAMPFIRE_DIR=${1:-/opt/once-campfire}

version_ge() {
    lower=$(printf '%s\n%s\n' "$1" "$2" | sort -V | sed -n '1p')
    [ "$lower" = "$2" ]
}

if [ ! -d "$ONCE_CAMPFIRE_DIR" ]; then
    echo "ERROR: once-campfire directory not found: ${ONCE_CAMPFIRE_DIR}" >&2
    exit 1
fi

cd "$ONCE_CAMPFIRE_DIR"

target="$MIN_RUBY_VERSION"

if [ -f .ruby-version ]; then
    current=$(tr -d '[:space:]' < .ruby-version)
    if [ -n "$current" ] && version_ge "$current" "$target"; then
        target="$current"
    fi
fi

if [ -f Dockerfile ]; then
    arg_ruby=$(sed -n 's/^ARG RUBY_VERSION=//p' Dockerfile | sed -n '1p')
    if [ -n "$arg_ruby" ] && version_ge "$arg_ruby" "$target"; then
        target="$arg_ruby"
    fi
    from_ruby=$(sed -n 's|^FROM \(docker\.io/library/\)\{0,1\}ruby:\([0-9.]*\)-slim.*|\2|p' Dockerfile | sed -n '1p')
    if [ -n "$from_ruby" ] && version_ge "$from_ruby" "$target"; then
        target="$from_ruby"
    fi
fi

if [ -f .ruby-version ]; then
    printf '%s\n' "$target" > .ruby-version
fi

if [ -f Dockerfile ]; then
    if grep -q '^ARG RUBY_VERSION=' Dockerfile; then
        sed "s/^ARG RUBY_VERSION=.*/ARG RUBY_VERSION=${target}/" Dockerfile > Dockerfile.tmp
        mv Dockerfile.tmp Dockerfile
    fi
    sed "s|^FROM \\(\\(docker\\.io/library/\\)\\{0,1\\}\\)ruby:[0-9.]*-slim|FROM \\1ruby:${target}-slim|" Dockerfile > Dockerfile.tmp
    mv Dockerfile.tmp Dockerfile
fi

echo "Ensured once-campfire Ruby ${target} (minimum ${MIN_RUBY_VERSION}, CVE-2026-132825)"
ENSURE_EOF

cat > /opt/verify-campfire-ruby.sh << 'VERIFY_EOF'
#!/bin/sh
set -eu

MIN_RUBY_VERSION=4.0.10
IMAGE=${1:-campfire}

version_ge() {
    lower=$(printf '%s\n%s\n' "$1" "$2" | sort -V | sed -n '1p')
    [ "$lower" = "$2" ]
}

actual=$(docker run --rm "$IMAGE" ruby -e 'print RUBY_VERSION')
if ! version_ge "$actual" "$MIN_RUBY_VERSION"; then
    echo "ERROR: Campfire image Ruby ${actual} is below minimum ${MIN_RUBY_VERSION} (CVE-2026-132825)" >&2
    exit 1
fi
echo "Campfire image Ruby ${actual} meets minimum ${MIN_RUBY_VERSION} (CVE-2026-132825)"
VERIFY_EOF

chmod +x /opt/ensure-campfire-ruby.sh /opt/verify-campfire-ruby.sh

# git clone the repo
cd /opt && git clone https://github.com/basecamp/once-campfire.git

# Create environment file (SECRET_KEY_BASE will be generated on first boot)
cat > /opt/campfire.env << EOF
# Campfire Environment Configuration
# 
# After making changes to this file, restart Campfire with:
#   /opt/restart-campfire.sh

# Rails application secret key for session encryption and security
# This will be automatically generated on first boot for security
SECRET_KEY_BASE=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Disable SSL/TLS termination in the container (useful when using a reverse proxy)
DISABLE_SSL=true

# Web Push notification public key (uncomment and set for push notifications)
# VAPID_PUBLIC_KEY=$YOUR_PUBLIC_KEY

# Web Push notification private key (uncomment and set for push notifications)
# VAPID_PRIVATE_KEY=$YOUR_PRIVATE_KEY

# Domain name for automatic SSL certificate generation (uncomment and set your domain)
# TLS_DOMAIN=chat.example.com
EOF

# BuildKit + buildx required for COPY --chmod in once-campfire Dockerfile
# (Ubuntu docker.io does not ship a working buildx by default).
if ! docker buildx version >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq docker-buildx
fi
/opt/ensure-campfire-ruby.sh /opt/once-campfire
cd /opt/once-campfire && DOCKER_BUILDKIT=1 docker build -t campfire .
/opt/verify-campfire-ruby.sh campfire

# Get the latest version of campfire
cd /opt/once-campfire && docker run \
  --detach \
  --name campfire \
  --publish 80:80 --publish 443:443 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire

# Create a helper script to restart Campfire with updated environment
cat > /opt/restart-campfire.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "Stopping and removing existing Campfire container..."
docker stop campfire 2>/dev/null || true
docker rm campfire 2>/dev/null || true

echo "Starting Campfire with updated environment..."
# ! binds only to the next pipeline; wrap so both cd and docker run are negated.
if ! (cd /opt/once-campfire && docker run \
  --detach \
  --name campfire \
  --publish 80:80 --publish 443:443 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire); then
  echo "❌ Error: Failed to start Campfire container" >&2
  exit 1
fi

# docker run -d can succeed even if the process exits immediately
for _ in $(seq 1 15); do
  if [ "$(docker inspect -f '{{.State.Running}}' campfire 2>/dev/null)" = "true" ]; then
    echo "Campfire restarted successfully!"
    exit 0
  fi
  sleep 1
done

echo "❌ Error: Campfire container is not running after start" >&2
exit 1
EOF

# Create an update script to update Campfire to latest version
cat > /opt/update-campfire.sh << 'EOF'
#!/bin/bash

# Campfire Update Script
# Pulls latest once-campfire, rebuilds the image, then cuts over.
# Keeps the existing container running until the new image build succeeds
# so a failed/slow rebuild does not leave the droplet with no Campfire.

echo "Updating Campfire to latest version..."

if [ ! -d "/opt/once-campfire" ]; then
    echo "Error: Campfire installation directory not found at /opt/once-campfire"
    exit 1
fi

cd /opt/once-campfire

echo "Pulling latest code from GitHub..."
if ! git pull origin main; then
    echo "ℹ️  git pull failed; leaving running container as-is."
    exit 1
fi

/opt/ensure-campfire-ruby.sh /opt/once-campfire

echo "Rebuilding Campfire image (existing container kept until build succeeds)..."
# BuildKit + buildx required for COPY --chmod in once-campfire Dockerfile
ensure_docker_buildx() {
  if docker buildx version >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing docker-buildx (required for Campfire image builds)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq docker-buildx
  docker buildx version >/dev/null 2>&1
}

if ! ensure_docker_buildx; then
  echo "❌ Error: docker-buildx is missing/broken; cannot rebuild Campfire image." >&2
  echo "   Install with: apt-get install -y docker-buildx" >&2
  exit 1
fi

if ! DOCKER_BUILDKIT=1 docker build -t campfire .; then
    echo "❌ Error: Failed to rebuild Campfire image; leaving running container as-is."
    exit 1
fi

if ! /opt/verify-campfire-ruby.sh campfire; then
    echo "❌ Error: Rebuilt Campfire image failed Ruby CVE verification; leaving running container as-is."
    exit 1
fi

echo "Starting Campfire with updated image..."
if [ -x "/opt/restart-campfire.sh" ] && /opt/restart-campfire.sh; then
    echo "✅ Campfire updated and restarted successfully!"
    exit 0
fi

if [ -x "/opt/restart-campfire.sh" ]; then
    echo "⚠️  /opt/restart-campfire.sh failed; attempting fallback docker run..." >&2
fi

docker stop campfire 2>/dev/null || true
docker rm campfire 2>/dev/null || true
if ! docker run \
  --detach \
  --name campfire \
  --publish 80:80 --publish 443:443 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire; then
  echo "❌ Error: Failed to start Campfire" >&2
  exit 1
fi

# docker run -d can succeed even if the process exits immediately
for _ in $(seq 1 15); do
  if [ "$(docker inspect -f '{{.State.Running}}' campfire 2>/dev/null)" = "true" ]; then
    echo "✅ Campfire updated and restarted successfully!"
    exit 0
  fi
  sleep 1
done

echo "❌ Error: Campfire container is not running after fallback start" >&2
exit 1
EOF

chmod +x /opt/restart-campfire.sh
chmod +x /opt/update-campfire.sh
