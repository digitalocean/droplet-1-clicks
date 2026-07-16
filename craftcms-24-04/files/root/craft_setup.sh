#!/bin/bash
#
# Craft CMS setup script (WordPress wp_setup.sh pattern).
# Runs on first SSH login. Users can also finish setup in the browser.

set -e

MARKER=/root/.craft_setup_complete

# Already completed
if [ -f "${MARKER}" ]; then
  sed -i '/craft_setup.sh/d' /root/.bashrc 2>/dev/null || true
  exit 0
fi

# Skip if Craft is already installed
if php /var/www/craft/craft install/check >/dev/null 2>&1; then
  touch "${MARKER}"
  sed -i '/craft_setup.sh/d' /root/.bashrc 2>/dev/null || true
  exit 0
fi

myip=$(hostname -I | awk '{print$1}')

echo "================================================================"
echo "Craft CMS Setup"
echo "================================================================"
echo ""
echo "Craft CMS files and database are ready."
echo "You can finish setup in the browser at: http://${myip}"
echo "Or continue here to create the admin account via CLI."
echo ""

read -p "Continue with CLI setup now? [Y/n] " proceed
proceed=${proceed:-Y}
if [[ ! "${proceed}" =~ ^[Yy]$ ]]; then
  echo "Skipping CLI setup. Visit http://${myip} to finish installation."
  exit 0
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

site_url="http://${myip}"

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

chown -R www-data:www-data /var/www/craft
touch "${MARKER}"
sed -i '/craft_setup.sh/d' /root/.bashrc 2>/dev/null || true

echo ""
echo "Craft CMS is ready!"
echo "  Front-end:      ${site_url}"
echo "  Control Panel:  ${site_url}/admin"
echo ""
echo "To enable HTTPS with a domain:"
echo "  certbot --nginx -d your.domain"
echo ""
