#!/bin/bash
# filepath: /Users/sbhadra/droplet-1-clicks/plausible-24-04/files/root/plausible-setup.sh

set -e  # Exit on any error

INSTALL_DIR="/docker/plausible"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

git clone https://github.com/plausible/hosting .

droplet_ip=$(hostname -I | awk '{print$1}')

# Interactive setup
echo "=== Plausible Analytics Setup ==="
read -p "Enter your admin email: " admin_email
read -p "Enter your desired admin name: " admin_name
read -s -p "Enter your desired admin password: " admin_pwd
echo

# Generate secure secret
secret_key_base=$(openssl rand -base64 48)

cat > .env <<EOF
BASE_URL=http://$droplet_ip
SECRET_KEY_BASE=$secret_key_base
ADMIN_USER_EMAIL=$admin_email
ADMIN_USER_NAME=$admin_name
ADMIN_USER_PWD=$admin_pwd
DATABASE_URL=postgresql://postgres:postgres@plausible_db:5432/plausible
CLICKHOUSE_DATABASE_URL=http://plausible_events_db:8123/plausible
EOF

sed -i '/plausible:/a \ \ \ \ ports:\n\ \ \ \ \ \ - 8000:8000' compose.yml
sed -i "s|- BASE_URL.*|- BASE_URL=\${BASE_URL}|" compose.yml
sed -i "s|- SECRET_KEY_BASE.*|- SECRET_KEY_BASE=\${SECRET_KEY_BASE}|" compose.yml
sed -i "s|- DATABASE_URL.*|- DATABASE_URL=\${DATABASE_URL}|" compose.yml
sed -i "s|- CLICKHOUSE_DATABASE_URL.*|- CLICKHOUSE_DATABASE_URL=\${CLICKHOUSE_DATABASE_URL}|" compose.yml
sed -i "/# required:.*$/a \ \ \ \ \ \ - ADMIN_USER_EMAIL=\${ADMIN_USER_EMAIL}\n\ \ \ \ \ \ - ADMIN_USER_NAME=\${ADMIN_USER_NAME}\n\ \ \ \ \ \ - ADMIN_USER_PWD=\${ADMIN_USER_PWD}" compose.yml

echo "Starting Plausible Analytics..."
docker-compose up -d

echo ""
echo "✅ Plausible Analytics is running!"
echo "📍 Access URL: http://$droplet_ip:8000"
echo "📧 Admin email: $admin_email"
echo ""
echo "Note: Configure your domain and SSL certificate for production use."