#!/bin/bash
#
# Craft CMS domain configuration (WordPress wp_setup_domain.sh pattern).

set -euo pipefail

if [ ! -f /root/.craft_setup_complete ]; then
  echo "ERROR: Finish first-login Craft setup before configuring a domain."
  echo "Run: /root/craft_setup.sh"
  echo "Until then, the public installer stays blocked (setup-pending)."
  exit 1
fi

echo "================================================================"
echo "Craft CMS Domain Setup"
echo "================================================================"
echo ""
echo "Configure Caddy with a custom domain and short-lived Let's Encrypt TLS."
echo "IMPORTANT: DNS A record must already point to this Droplet."
echo ""

current_ip=$(hostname -I | awk '{print$1}')
echo "This server's IP address: ${current_ip}"
echo ""

while true; do
  read -p "Enter your domain name (e.g., example.com or cms.example.com): " domain
  if [ -z "$domain" ]; then
    echo "Domain cannot be empty."
  else
    break
  fi
done

read -p "Enter your email for Let's Encrypt notifications (optional): " email

echo ""
echo "Configuring Caddy for domain: ${domain}"

sed -e "s|PLACEHOLDER_DOMAIN|${domain}|g" \
    -e "s|PLACEHOLDER_EMAIL|${email}|g" \
    /etc/caddy/Caddyfile.domain > /etc/caddy/Caddyfile

# Drop empty email line if user skipped email
if [ -z "$email" ]; then
  sed -i '/email $/d' /etc/caddy/Caddyfile
fi

systemctl reload caddy
sleep 3

site_url="https://${domain}"

# Update Craft primary site URL (Craft 5 uses PRIMARY_SITE_URL in .env)
if [ -f /var/www/craft/.env ]; then
  if grep -q '^PRIMARY_SITE_URL=' /var/www/craft/.env; then
    sed -i "s|^PRIMARY_SITE_URL=.*|PRIMARY_SITE_URL=\"${site_url}\"|" /var/www/craft/.env
  else
    echo "PRIMARY_SITE_URL=\"${site_url}\"" >> /var/www/craft/.env
  fi
  chmod 640 /var/www/craft/.env
  chown www-data:www-data /var/www/craft/.env
fi

cd /var/www/craft
sudo -u www-data php craft clear-caches/all --interactive=0 >/dev/null 2>&1 || true
sudo -u www-data php craft project-config/apply --interactive=0 >/dev/null 2>&1 || true

echo ""
echo "================================================================"
echo "Domain setup complete"
echo "================================================================"
echo ""
echo "  Site:           ${site_url}"
echo "  Control Panel:  ${site_url}/admin"
echo "  PRIMARY_SITE_URL updated in /var/www/craft/.env"
echo ""
echo "================================================================"
echo ""
