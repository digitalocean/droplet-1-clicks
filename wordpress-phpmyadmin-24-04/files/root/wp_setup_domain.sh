#!/bin/bash
#
# WordPress + phpMyAdmin domain configuration script
#
# This script will configure Caddy with a custom domain
# and obtain a standard Let's Encrypt SSL certificate

set -euo pipefail

echo "================================================================"
echo "WordPress + phpMyAdmin Domain Setup"
echo "================================================================"
echo ""
echo "This script will configure your WordPress site and phpMyAdmin with a"
echo "custom domain and obtain a Let's Encrypt SSL certificate."
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

# Install shipped domain Caddyfile template
cp /etc/caddy/Caddyfile.domain /etc/caddy/Caddyfile
sed -i "s|PLACEHOLDER_DOMAIN|${domain}|g" /etc/caddy/Caddyfile
if [ -n "$email" ]; then
  sed -i "s|PLACEHOLDER_EMAIL|${email}|g" /etc/caddy/Caddyfile
else
  # Remove global options block when no email was provided
  sed -i '/^{$/,/^}$/d' /etc/caddy/Caddyfile
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
echo "phpMyAdmin:  https://$domain/phpmyadmin"
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
