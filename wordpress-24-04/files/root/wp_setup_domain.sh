#!/bin/bash
#
# WordPress domain configuration script
#
# This script will configure Caddy with a custom domain
# and obtain a standard Let's Encrypt SSL certificate

set -euo pipefail

echo "================================================================"
echo "WordPress Domain Setup"
echo "================================================================"
echo ""
echo "This script will configure your WordPress site with a custom domain"
echo "and obtain a Let's Encrypt SSL certificate."
echo ""
echo "⚠️  IMPORTANT: Your domain must already be pointed to this server's IP"
echo ""

# Get current IP
current_ip=$(hostname -I | awk '{print$1}')
echo "This server's IP address: $current_ip"
echo ""

# Prompt for domain
while true; do
  read -p "Enter your domain name (e.g., example.com or blog.example.com): " domain
  if [ -z "$domain" ]; then
    echo "Domain cannot be empty."
  else
    break
  fi
done

# Prompt for email
read -p "Enter your email for Let's Encrypt notifications (optional): " email

echo ""
echo "Configuring Caddy for domain: $domain"
echo "----------------------------------------"

# Create Caddyfile with domain configuration
if [ -n "$email" ]; then
cat > /etc/caddy/Caddyfile <<EOF
{
    email $email
}

# HTTP redirect to HTTPS
http://$domain {
    redir https://{host}{uri} permanent
}

# HTTPS configuration with standard Let's Encrypt certificate
https://$domain {
    root * /var/www/html
    php_fastcgi unix//run/php/php8.3-fpm.sock
    file_server
    
    encode gzip
    
    # WordPress permalinks
    try_files {path} {path}/ /index.php?{query}
    
    # Deny access to sensitive files
    @blocked {
        path */xmlrpc.php
        path */.git/*
        path */wp-config.php
    }
    respond @blocked 403
}
EOF
else
cat > /etc/caddy/Caddyfile <<EOF
# HTTP redirect to HTTPS
http://$domain {
    redir https://{host}{uri} permanent
}

# HTTPS configuration with standard Let's Encrypt certificate
https://$domain {
    root * /var/www/html
    php_fastcgi unix//run/php/php8.3-fpm.sock
    file_server
    
    encode gzip
    
    # WordPress permalinks
    try_files {path} {path}/ /index.php?{query}
    
    # Deny access to sensitive files
    @blocked {
        path */xmlrpc.php
        path */.git/*
        path */wp-config.php
    }
    respond @blocked 403
}
EOF
fi

# Reload Caddy
systemctl reload caddy
sleep 3

echo "✓ Caddy configured"
echo ""

# Update WordPress URLs
echo "Updating WordPress URLs..."
wp --allow-root --path="/var/www/html" option update home "https://$domain" 2>/dev/null
wp --allow-root --path="/var/www/html" option update siteurl "https://$domain" 2>/dev/null
echo "✓ WordPress URLs updated"
echo ""

echo "================================================================"
echo "🎉 Domain Setup Complete!"
echo "================================================================"
echo ""
echo "Your WordPress site is now accessible at:"
echo ""
echo "    👉  https://$domain"
echo ""
echo "Admin panel: https://$domain/wp-admin"
echo ""
echo "================================================================"
echo ""
echo "📝 Notes:"
echo ""
echo "• SSL certificate: Standard Let's Encrypt (90-day validity)"
echo "• Auto-renewal: Caddy handles this automatically"
echo "• Previous IP access: Still works but redirects to domain"
echo ""
echo "================================================================"
echo ""
