#!/bin/bash
#
# WordPress automatic setup script with IP-based SSL
#
# This script automatically configures Apache and WordPress with
# an IP-based SSL certificate from Let's Encrypt

set -e  # Exit on error

echo "================================================================"
echo "WordPress Automatic Setup"
echo "================================================================"
echo ""
echo "This script will automatically configure your WordPress installation"
echo "with HTTPS using Let's Encrypt SSL certificate for your server's IP."
echo ""

# Enable WordPress on first login
if [[ -d /var/www/wordpress ]]
then
  mv /var/www/html /var/www/html.old 2>/dev/null || true
  mv /var/www/wordpress /var/www/html
fi
chown -Rf www-data:www-data /var/www/html

# if applicable, configure wordpress to use mysql dbaas
if [ -f "/root/.digitalocean_dbaas_credentials" ] && [ "$(sed -n "s/^db_protocol=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)" = "mysql" ]; then
  # grab all the data from the password file
  username=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  password=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  host=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  port=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  database=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

  # update the wp-config.php with stored credentials
  sed -i "s/'DB_USER', '.*'/'DB_USER', '$username'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_NAME', '.*'/'DB_NAME', '$database'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_PASSWORD', '.*'/'DB_PASSWORD', '$password'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_HOST', '.*'/'DB_HOST', '$host:$port'/g" /var/www/html/wp-config.php;

  # add required SSL flag
  cat >> /var/www/html/wp-config.php <<EOM
/** Connect to MySQL cluster over SSL **/
define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL );
EOM

  # wait for db to become available
  echo -e "\nWaiting for your database to become available (this may take a few minutes)"
  while ! mysqladmin ping -h "$host" -P "$port" --silent; do
      printf .
      sleep 2
  done
  echo -e "\nDatabase available!\n"

  # cleanup
  unset username password host port database
  rm -f /root/.digitalocean_dbaas_credentials

  # disable the local MySQL instance
  systemctl stop mysql.service
  systemctl disable mysql.service
fi

echo "Step 1: Detecting server IP address..."
echo "----------------------------------------"

# Get the server's IP address
server_ip=$(hostname -I | awk '{print$1}')

if [ -z "$server_ip" ]; then
  echo "ERROR: Could not automatically detect server IP address."
  echo "Please manually run: /root/wp_setup_domain.sh for domain-based setup"
  exit 1
fi

echo "✓ Detected IP address: $server_ip"
echo ""

echo "Step 2: WordPress Admin Account Setup"
echo "----------------------------------------"

function wordpress_admin_account(){

  while [ -z "$email" ]
  do
    read -p "Your Email Address: " email
  done

  while [ -z "$username" ]
  do
    read -p "Admin Username: " username
  done

  while [ -z "$pass" ]
  do
    read -s -p "Admin Password: " pass
    echo ""
  done

  while [ -z "$title" ]
  do
    read -p "Site Title: " title
  done
}

wordpress_admin_account

echo ""
while true
do
    read -p "Is the information correct? [Y/n] " confirmation
    confirmation=${confirmation,,}
    if [[ "${confirmation}" =~ ^(yes|y)$ ]] || [ -z $confirmation ]
    then
      break
    else
      unset email username pass title confirmation
      echo ""
      wordpress_admin_account
      echo ""
    fi
done

echo ""
echo "Step 3: Installing WP-CLI..."
echo "----------------------------------------"
wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/bin/wp 2>/dev/null
chmod +x /usr/bin/wp
echo "✓ WP-CLI installed"
echo ""

echo "Step 4: Configuring WordPress..."
echo "----------------------------------------"
wp core install --allow-root --path="/var/www/html" --title="$title" --url="http://$server_ip" --admin_email="$email" --admin_password="$pass" --admin_user="$username" 2>/dev/null
echo "✓ WordPress configured"
echo ""

echo "Step 5: Configuring Caddy with SSL..."
echo "----------------------------------------"
echo "Setting up automatic HTTPS with short-lived certificates for $server_ip"
echo ""

# Create Caddyfile with short-lived certificate configuration
cat > /etc/caddy/Caddyfile <<EOF
# Global options
{
    email $email
}

# HTTP configuration (for setup)
http://$server_ip {
    redir https://{host}{uri} permanent
}

# HTTPS configuration with short-lived certificates
https://$server_ip {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    
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

# Reload Caddy
systemctl enable caddy 2>/dev/null
systemctl restart caddy

echo "✓ Caddy configured with automatic HTTPS"
echo ""

echo "Step 6: Installing security plugins..."
echo "----------------------------------------"
sleep 3

# Update WordPress URLs to use HTTPS
wp --allow-root --path="/var/www/html" option update home "https://$server_ip" 2>/dev/null
wp --allow-root --path="/var/www/html" option update siteurl "https://$server_ip" 2>/dev/null

wp plugin install wp-fail2ban --allow-root --path="/var/www/html" 2>/dev/null
wp plugin activate wp-fail2ban --allow-root --path="/var/www/html" 2>/dev/null
echo "✓ Security plugins installed"
echo ""

chown -Rf www-data:www-data /var/www/
cp /etc/skel/.bashrc /root

echo ""
echo "================================================================"
echo "🎉 WordPress Installation Complete!"
echo "================================================================"
echo ""
echo "Your WordPress site is now accessible at:"
echo ""
echo "    👉  https://$server_ip"
echo ""
echo "Admin login:"
echo "    Username: $username"
echo "    Email: $email"
echo ""
echo "================================================================"
echo ""
echo "📝 Additional Information:"
echo ""
echo "• SSL: Short-lived certificates (auto-renew every ~6 days)"
echo "• Web server: Caddy (automatic HTTPS)"
echo "• Add custom domain: /root/wp_setup_domain.sh"
echo ""
echo "================================================================"
echo ""
