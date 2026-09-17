#!/bin/bash

export TERM=xterm-256color

# prevent locale warnings
touch /var/lib/cloud/instance/locale-check.skip

GHOST_HOST="${DATABASE_HOST:-127.0.0.1}"
GHOST_PORT="${DATABASE_PORT:-3306}"
GHOST_DATABASE="${DATABASE_DB:-ghost_production}"

# localhost / ::1 are local MySQL, same as 127.0.0.1. Normalize to IPv4 so
# Ghost/Node do not resolve "localhost" to ::1 and fail with ECONNREFUSED.
case "$GHOST_HOST" in
    127.0.0.1|localhost|::1)
        LOCAL_MYSQL=1
        GHOST_HOST=127.0.0.1
        ;;
    *)
        LOCAL_MYSQL=0
        ;;
esac

# Reuse passwords on retry so we don't lock ourselves out of MySQL
if [ -f /root/.digitalocean_password ]; then
    # shellcheck disable=SC1091
    source /root/.digitalocean_password
fi

if [ "$LOCAL_MYSQL" -eq 1 ]; then
    # Dedicated app user (non-root) so Ghost-CLI skips its own MySQL user creation
    GHOST_USERNAME="${DATABASE_USERNAME:-ghost}"
    ROOT_MYSQL_PASS="${root_mysql_pass:-$(openssl rand -hex 24)}"
    if [ "$GHOST_USERNAME" = "root" ]; then
        GHOST_PASSWORD="${DATABASE_PASSWORD:-$ROOT_MYSQL_PASS}"
        ROOT_MYSQL_PASS="$GHOST_PASSWORD"
    else
        GHOST_PASSWORD="${DATABASE_PASSWORD:-${ghost_mysql_pass:-$(openssl rand -hex 24)}}"
    fi
else
    GHOST_USERNAME="${DATABASE_USERNAME:-root}"
    GHOST_PASSWORD="${DATABASE_PASSWORD:-${root_mysql_pass:-$(openssl rand -hex 24)}}"
    ROOT_MYSQL_PASS="$GHOST_PASSWORD"
fi

myip=$(hostname -I | awk '{print$1}')

# Ensure MySQL is running (socket ping is reliable on first boot)
if [ "$LOCAL_MYSQL" -eq 1 ]; then
    while ! mysqladmin ping -h localhost --silent; do sleep 1; done
else
    while ! mysqladmin ping -h"$GHOST_HOST" -P"$GHOST_PORT" --silent; do sleep 1; done
fi

# Save the passwords
cat > /root/.digitalocean_password <<EOM
root_mysql_pass="${ROOT_MYSQL_PASS}"
ghost_mysql_pass="${GHOST_PASSWORD}"
EOM

# Set up Postfix defaults
hostname=$(hostname)
sed -i "s/myhostname \= ghost/myhostname = $hostname/g" /etc/postfix/main.cf;
sed -i "s/inet_interfaces = all/inet_interfaces = loopback-only/g" /etc/postfix/main.cf;
systemctl restart postfix &

# Run a MySQL statement as root via unix_socket (fresh install) or password (retry)
mysql_as_root() {
    if mysql -u root -h localhost -e "SELECT 1" &>/dev/null; then
        mysql -u root -h localhost "$@"
    else
        mysql -u root -h localhost -p"${ROOT_MYSQL_PASS}" "$@"
    fi
}

# If we're running the DB locally, configure root + a dedicated Ghost DB user
if [ "$LOCAL_MYSQL" -eq 1 ]; then
    if ! mysql_as_root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${ROOT_MYSQL_PASS}'; FLUSH PRIVILEGES;"; then
        echo "Failed to set MySQL root password" >&2
        exit 1
    fi

    if ! mysql -u root -h localhost -p"${ROOT_MYSQL_PASS}" -e "
        CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '${ROOT_MYSQL_PASS}';
        ALTER USER 'root'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '${ROOT_MYSQL_PASS}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;

        CREATE DATABASE IF NOT EXISTS \`${GHOST_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

        CREATE USER IF NOT EXISTS '${GHOST_USERNAME}'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
        CREATE USER IF NOT EXISTS '${GHOST_USERNAME}'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
        ALTER USER '${GHOST_USERNAME}'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
        ALTER USER '${GHOST_USERNAME}'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${GHOST_DATABASE}\`.* TO '${GHOST_USERNAME}'@'127.0.0.1';
        GRANT ALL PRIVILEGES ON \`${GHOST_DATABASE}\`.* TO '${GHOST_USERNAME}'@'localhost';
        FLUSH PRIVILEGES;
    "; then
        echo "Failed setting up Ghost MySQL database/user" >&2
        exit 1
    fi

    debian_sys_maint_mysql_pass=$(openssl rand -hex 24)
    mysql -u root -h localhost -p"${ROOT_MYSQL_PASS}" \
        -e "ALTER USER 'debian-sys-maint'@'localhost' IDENTIFIED BY '${debian_sys_maint_mysql_pass}'" 2>/dev/null

    cat > /etc/mysql/debian.cnf <<EOM
# Automatically generated for Debian scripts. DO NOT TOUCH!
[client]
host     = localhost
user     = debian-sys-maint
password = ${debian_sys_maint_mysql_pass}
socket   = /var/run/mysqld/mysqld.sock
[mysql_upgrade]
host     = localhost
user     = debian-sys-maint
password = ${debian_sys_maint_mysql_pass}
socket   = /var/run/mysqld/mysqld.sock
EOM
else
    systemctl stop mysql 2>/dev/null
    systemctl disable mysql 2>/dev/null
fi

# This is where the magic starts

echo "
Ghost will prompt you for two details:

1. Your domain
 - Add an A Record -> $(tput setaf 6)${myip}$(tput sgr0) & ensure the DNS has fully propagated
 - Or alternatively enter $(tput setaf 6)http://${myip}$(tput sgr0)
2. Your email address (only used for SSL)

$(tput setaf 2)Press enter when you're ready to get started!$(tput sgr0)
"

# Make sure the user is ready to install Ghost
read wait

source /var/lib/digitalocean/application.info
# Install Ghost (non-root DB user skips Ghost-CLI MySQL user creation)
sudo -iu ghost-mgr ghost install "$application_version" --auto \
  --db=mysql \
  --dbhost="$GHOST_HOST" \
  --dbport="$GHOST_PORT" \
  --dbname="$GHOST_DATABASE" \
  --dbuser="$GHOST_USERNAME" \
  --dbpass="$GHOST_PASSWORD" \
  --dir=/var/www/ghost \
  --start


# Final cleanup
cp /opt/ghost-setup/99-one-click /etc/update-motd.d/99-one-click
chmod 0755 /etc/update-motd.d/99-one-click

# Remove nginx default site
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx
