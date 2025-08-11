#!/bin/bash
# filepath: /Users/sbhadra/droplet-1-clicks/plausible-24-04/files/root/plausible-setup.sh

set -e

INSTALL_DIR="/docker/plausible"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

git clone https://github.com/plausible/hosting .

droplet_ip=$(hostname -I | awk '{print$1}')

echo "=== Plausible Analytics Setup ==="
echo ""
echo "Choose your setup method:"
echo "1. Use server IP address (quick setup) - http://$droplet_ip"
echo "2. Use your own domain (recommended for production) - https://yourdomain.com"
echo ""
read -p "Enter your choice (1 or 2): " setup_choice

if [ "$setup_choice" = "2" ]; then
    echo ""
    read -p "Enter your domain name (e.g., analytics.yourdomain.com): " user_domain
    
    if [[ ! "$user_domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$ ]]; then
        echo "❌ Invalid domain format. Please use a valid domain name."
        exit 1
    fi
    
    echo ""
    echo "📋 DNS Configuration Required:"
    echo "   Create an A record pointing '$user_domain' to $droplet_ip"
    echo ""
    read -p "Have you configured the DNS record? (y/n): " dns_ready
    
    if [ "$dns_ready" != "y" ]; then
        echo "⚠️  Please configure your DNS first, then run this script again."
        exit 1
    fi
    
    base_url="https://$user_domain"
    use_domain=true
else
    base_url="http://$droplet_ip"
    use_domain=false
fi

echo ""
read -p "Enter your admin email: " admin_email
read -p "Enter your desired admin name: " admin_name
read -s -p "Enter your desired admin password: " admin_pwd
echo

secret_key_base=$(openssl rand -base64 64)

cat > .env <<EOF
BASE_URL=$base_url
SECRET_KEY_BASE=$secret_key_base
ADMIN_USER_EMAIL=$admin_email
ADMIN_USER_NAME=$admin_name
ADMIN_USER_PWD=$admin_pwd
DATABASE_URL=postgresql://postgres:postgres@plausible_db:5432/plausible
CLICKHOUSE_DATABASE_URL=http://plausible_events_db:8123/plausible
EOF

# Configure Docker Compose
sed -i '/plausible:/a \ \ \ \ ports:\n\ \ \ \ \ \ - 127.0.0.1:8000:8000' compose.yml
sed -i "s|- BASE_URL.*|- BASE_URL=\${BASE_URL}|" compose.yml
sed -i "s|- SECRET_KEY_BASE.*|- SECRET_KEY_BASE=\${SECRET_KEY_BASE}|" compose.yml
sed -i "s|- DATABASE_URL.*|- DATABASE_URL=\${DATABASE_URL}|" compose.yml
sed -i "s|- CLICKHOUSE_DATABASE_URL.*|- CLICKHOUSE_DATABASE_URL=\${CLICKHOUSE_DATABASE_URL}|" compose.yml
sed -i "/# required:.*$/a \ \ \ \ \ \ - ADMIN_USER_EMAIL=\${ADMIN_USER_EMAIL}\n\ \ \ \ \ \ - ADMIN_USER_NAME=\${ADMIN_USER_NAME}\n\ \ \ \ \ \ - ADMIN_USER_PWD=\${ADMIN_USER_PWD}" compose.yml

# Configure Nginx based on user choice
if [ "$use_domain" = true ]; then
    echo "🔧 Setting up domain configuration..."
    
    # Disable the default IP configuration
    rm -f /etc/nginx/sites-enabled/plausible.conf
    
    # Create domain-specific configuration
    cat > /etc/nginx/sites-available/plausible-domain <<EOF
server {
    listen 80;
    server_name $user_domain;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    ln -sf /etc/nginx/sites-available/plausible-domain /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    echo "🚀 Starting Plausible Analytics..."
    docker-compose up -d
    
    echo "⏳ Waiting for Plausible to start..."
    sleep 30
    
    echo "🔒 Setting up SSL certificate..."
    if certbot --nginx -d "$user_domain" --non-interactive --agree-tos --email "$admin_email" --redirect; then
        sed -i "s|BASE_URL=.*|BASE_URL=https://$user_domain|" .env
        docker-compose restart plausible
        access_url="https://$user_domain"
        echo "✅ SSL certificate installed!"
    else
        access_url="http://$user_domain"
        echo "⚠️  SSL setup failed."
    fi
    
else
    echo "🔧 Using IP configuration..."
    # Keep the existing IP configuration from 013 script
    
    echo "🚀 Starting Plausible Analytics..."
    docker-compose up -d
    
    access_url="http://$droplet_ip"
fi

sleep 30

echo ""
echo "🎉 Plausible Analytics is ready!"
echo "📍 Access URL: $access_url"
echo "📧 Admin Email: $admin_email"
echo ""

if [ "$use_domain" = true ]; then
    echo "🔒 SSL: Enabled"
    echo "🌐 Domain: $user_domain"
    echo "✅ Production ready!"
else
    echo "📝 For production: re-run with option 2 for domain setup"
fi

echo ""
echo "🚀 Visit $access_url to start using Plausible!"