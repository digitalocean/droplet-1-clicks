#!/bin/bash
#
# Craft CMS first-login setup (WordPress wp_setup.sh pattern).
# Creates the admin account via CLI and enables Caddy HTTPS (shortlived IP certs).
# Public web installer is gated until this completes.

set -e

MARKER=/root/.craft_setup_complete

clear_setup_bashrc() {
  sed -i \
    -e '/\/root\/craft_setup\.sh/d' \
    -e '/\/root\/craft_setup_domain\.sh/d' \
    /root/.bashrc 2>/dev/null || true
}

enable_ip_https() {
  local server_ip
  server_ip=$(hostname -I | awk '{print$1}')
  if [ -z "$server_ip" ]; then
    echo "WARNING: Could not detect server IP; HTTPS not configured."
    echo "Run /root/craft_setup_domain.sh after DNS is configured."
    return 1
  fi
  sed -e "s|PLACEHOLDER_EMAIL||g" \
      -e "s|PLACEHOLDER_IP|${server_ip}|g" \
      /etc/caddy/Caddyfile.ip > /etc/caddy/Caddyfile
  sed -i '/email $/d' /etc/caddy/Caddyfile
  systemctl enable caddy
  systemctl restart caddy
}

if [ -f "${MARKER}" ]; then
  clear_setup_bashrc
  exit 0
fi

if php /var/www/craft/craft install/check >/dev/null 2>&1; then
  enable_ip_https || true
  touch "${MARKER}"
  clear_setup_bashrc
  exit 0
fi

echo "================================================================"
echo "Craft CMS Setup"
echo "================================================================"
echo ""
echo "This wizard creates your admin account and enables HTTPS."
echo "The public installer is blocked until setup finishes."
echo ""

server_ip=$(hostname -I | awk '{print$1}')
if [ -z "$server_ip" ]; then
  echo "ERROR: Could not detect server IP."
  echo "Run /root/craft_setup_domain.sh after DNS is configured."
  exit 1
fi

email=""
username=""
pass=""
title=""

craft_admin_account() {
  while [ -z "$email" ]; do
    read -p "Admin Email Address: " email
  done
  while [ -z "$username" ]; do
    read -p "Admin Username: " username
  done
  while [ -z "$pass" ]; do
    read -s -p "Admin Password: " pass
    echo ""
  done
  while [ -z "$title" ]; do
    read -p "Site Name: " title
  done
}

craft_admin_account

echo ""
while true; do
  read -p "Is the information correct? [Y/n] " confirmation
  confirmation=${confirmation:-y}
  confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')
  if [[ "${confirmation}" =~ ^(yes|y)$ ]]; then
    break
  else
    email=""
    username=""
    pass=""
    title=""
    echo ""
    craft_admin_account
    echo ""
  fi
done

site_url="https://${server_ip}"

# Keep Craft site URL in sync via env (Craft 5 pattern)
if grep -q '^PRIMARY_SITE_URL=' /var/www/craft/.env 2>/dev/null; then
  sed -i "s|^PRIMARY_SITE_URL=.*|PRIMARY_SITE_URL=\"${site_url}\"|" /var/www/craft/.env
else
  echo "PRIMARY_SITE_URL=\"${site_url}\"" >> /var/www/craft/.env
fi

echo ""
echo "Installing Craft CMS..."
cd /var/www/craft
sudo -u www-data php craft install \
  --interactive=0 \
  --email="${email}" \
  --username="${username}" \
  --password="${pass}" \
  --site-name="${title}" \
  --site-url="${site_url}" \
  --language=en-US

echo "Configuring Caddy with short-lived HTTPS for ${server_ip}..."
sed -e "s|PLACEHOLDER_EMAIL|${email}|g" \
    -e "s|PLACEHOLDER_IP|${server_ip}|g" \
    /etc/caddy/Caddyfile.ip > /etc/caddy/Caddyfile

systemctl enable caddy
systemctl restart caddy

sudo -u www-data php craft clear-caches/all --interactive=0 >/dev/null 2>&1 || true

chown -R www-data:www-data /var/www/craft
chmod 640 /var/www/craft/.env
touch "${MARKER}"
clear_setup_bashrc

echo ""
echo "================================================================"
echo "Craft CMS is ready!"
echo "================================================================"
echo ""
echo "  Front-end:      ${site_url}"
echo "  Control Panel:  ${site_url}/admin"
echo ""
echo "  Add a custom domain: /root/craft_setup_domain.sh"
echo "  Manage services:     /opt/restart-craft.sh"
echo "  Status:              /opt/status-craft.sh"
echo ""
echo "================================================================"
echo ""
