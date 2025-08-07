#!/bin/bash
INSTALL_DIR="/docker/plausible"
mkdir -p "$INSTALL_DIR"

# Navigate to the installation directory
# All subsequent commands will be run from this directory
cd "$INSTALL_DIR" || exit 1

# Clone the Plausible hosting repository directly into the current directory
git clone https://github.com/plausible/hosting .

droplet_ip=$(hostname -I | awk '{print$1}')

# Prompt for user details
read -p "Enter your admin email: " admin_email
read -p "Enter your desired admin name: " admin_name
read -s -p "Enter your desired admin password: " admin_pwd
echo

# Generate a SECRET_KEY_BASE
secret_key_base=$(openssl rand -base64 12)

# Create and configure the .env file with dynamic and secret values
cat <<EOF > .env
BASE_URL=http://$droplet_ip
SECRET_KEY_BASE=$secret_key_base
EOF

sed -i '/plausible:/a \ \ \ \ ports:\n\ \ \ \ \ \ - 8000:8000' compose.yml


sed -i "/# required:.*$/a \ \ \ \ \ \ - ADMIN_USER_EMAIL=$admin_email\n\ \ \ \ \ \ - ADMIN_USER_NAME=$admin_name\n\ \ \ \ \ \ - ADMIN_USER_PWD=$admin_pwd" compose.yml

sed -i "s/- DATABASE_URL/- DATABASE_URL=postgresql:\/\/postgres:postgres@plausible_db:5432\/plausible/" compose.yml
sed -i "s/- CLICKHOUSE_DATABASE_URL/- CLICKHOUSE_DATABASE_URL=http:\/\/plausible_events_db:8123\/plausible/" compose.yml

sudo docker-compose up -d

echo "Plausible Analytics containers are running."