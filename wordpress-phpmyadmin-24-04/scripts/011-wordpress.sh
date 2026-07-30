#!/bin/sh
set -e

# Download the latest stable WordPress release at build time
wget -q https://wordpress.org/wordpress-latest.tar.gz -O /tmp/wordpress.tar.gz

mkdir -p /var/www
tar -C /var/www -xzf /tmp/wordpress.tar.gz
rm -f /tmp/wordpress.tar.gz

# WP-CLI for first-login setup (wrapper always passes --allow-root; Packer/Droplet run as root)
mkdir -p /usr/local/lib
wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/lib/wp-cli.phar
chmod +x /usr/local/lib/wp-cli.phar
cat > /usr/bin/wp <<'EOF'
#!/bin/sh
exec /usr/local/lib/wp-cli.phar --allow-root "$@"
EOF
chmod +x /usr/bin/wp

# Do not run `wp core update` here: wordpress-latest.tar.gz is already the current
# stable release, and wp-config.php is created with secrets in 001_onboot.

wget -q https://downloads.wordpress.org/plugin/wp-fail2ban.latest-stable.zip -O /tmp/wp-fail2ban.zip
unzip -q /tmp/wp-fail2ban.zip -d /tmp/

# install the fail2ban bits (plugin itself installed in first-login script)
mkdir -p /etc/fail2ban/filter.d
cp -au /tmp/wp-fail2ban/filters.d/* /etc/fail2ban/filter.d
rm -rf /tmp/wp-fail2ban.zip /tmp/wp-fail2ban
