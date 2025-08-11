#!/bin/bash


set -e

INSTALL_DIR="/docker/plausible"
SETUP_FLAG="/root/.plausible_setup_complete"

# Check if setup was already completed
if [ -f "$SETUP_FLAG" ]; then
    echo "=== Plausible Analytics - Already Configured ==="
    echo ""
    echo "Plausible Analytics is already set up on this server."
    echo ""
    echo "Current configuration:"
    if [ -f "$INSTALL_DIR/.env" ]; then
        base_url=$(grep "^BASE_URL=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
        admin_email=$(grep "^ADMIN_USER_EMAIL=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
        echo "📍 Access URL: $base_url"
        echo "📧 Admin Email: $admin_email"
    fi
    echo ""
    echo "Options:"
    echo "1. Access current installation"
    echo "2. Reconfigure (start over)"
    echo "3. Exit"
    echo ""
    read -p "Choose option (1-3): " rerun_choice
    
    case $rerun_choice in
        1)
            echo "✅ Current installation is ready!"
            if [ -f "$INSTALL_DIR/.env" ]; then
                base_url=$(grep "^BASE_URL=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
                echo "🚀 Visit: $base_url"
            fi
            exit 0
            ;;
        2)
            echo "🔄 Starting reconfiguration..."
            rm -f "$SETUP_FLAG"
            cd "$INSTALL_DIR" 2>/dev/null && docker-compose down 2>/dev/null || true
            ;;
        3)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Exiting."
            exit 1
            ;;
    esac
fi

# Main setup starts here
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# Clone or update repository
if [ -d ".git" ]; then
    echo "📦 Updating Plausible hosting repository..."
    git pull
else
    echo "📦 Cloning Plausible hosting repository..."
    git clone https://github.com/plausible/hosting .
fi

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
    echo "📋 DNS Configuration Required:"
    echo "   Create an A record pointing your domain to: $droplet_ip"
    echo ""
    
    read -p "Enter your domain name: " user_domain
    read -p "Have you configured the DNS A record? (y/n): " dns_ready
    
    if [ "$dns_ready" != "y" ]; then
        echo "⚠️  Setup cancelled. Configure DNS first, then run:"
        echo "   ./plausible-setup.sh"
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
    echo "🔧 Configuring domain setup..."
    
    rm -f /etc/nginx/sites-enabled/plausible.conf
    
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
        echo "⚠️  SSL setup failed. You can access via HTTP."
    fi
    
else
    echo "🔧 Using IP configuration..."
    
    echo "🚀 Starting Plausible Analytics..."
    docker-compose up -d
    
    access_url="http://$droplet_ip"
fi

sleep 15

# Mark setup as complete
touch "$SETUP_FLAG"

echo ""
echo "🎉 Plausible Analytics is ready!"
echo "📍 Access URL: $access_url"
echo "📧 Admin Email: $admin_email"
echo "👤 Admin Name: $admin_name"
echo ""

if [ "$use_domain" = true ]; then
    if [[ "$access_url" == https* ]]; then
        echo "🔒 SSL: Enabled"
        echo "✅ Production ready!"
    else
        echo "🔒 SSL: Not configured"
        echo "📝 Manual SSL: certbot --nginx -d $user_domain"
    fi
else
    echo "📝 For production: run ./plausible-setup.sh again (option 2)"
fi

echo ""
echo "🚀 Visit $access_url to start using Plausible!"
echo ""
echo "💡 To reconfigure later: run ./plausible-setup.sh"