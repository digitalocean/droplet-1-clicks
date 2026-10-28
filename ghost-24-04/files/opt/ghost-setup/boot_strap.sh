#!/bin/bash

export TERM=xterm-256color

# prevent locale warnings
touch /var/lib/cloud/instance/locale-check.skip

GHOST_HOST="${DATABASE_HOST:-127.0.0.1}"
GHOST_PORT="${DATABASE_PORT:-3306}"
GHOST_DATABASE="${DATABASE_DB:-ghost_production}"
GHOST_USERNAME="${DATABASE_USERNAME:-root}"

# Reuse password from a previous bootstrap attempt (e.g. ghost install failed
# after MySQL was already secured). Never overwrite a working password with a
# new random value before we can authenticate.
PASSWORD_FILE=/root/.digitalocean_password
if [ -z "${DATABASE_PASSWORD:-}" ] && [ -f "$PASSWORD_FILE" ]; then
    # shellcheck disable=SC1090
    . "$PASSWORD_FILE"
fi
GHOST_PASSWORD="${DATABASE_PASSWORD:-${root_mysql_pass:-$(openssl rand -hex 24)}}"

myip=$(hostname -I | awk '{print$1}')

# Ensure MySQL is running
while ! mysqladmin ping -h"$GHOST_HOST" -P "$GHOST_PORT" --silent; do sleep 1; done

# Set up Postfix defaults
hostname=$(hostname)
sed -i "s/myhostname \= ghost/myhostname = $hostname/g" /etc/postfix/main.cf;
sed -i "s/inet_interfaces = all/inet_interfaces = loopback-only/g" /etc/postfix/main.cf;
systemctl restart postfix &

# If we're running the DB locally, change the DB maintenance user password
if [ "$GHOST_HOST" = "127.0.0.1" ]; then
    if mysql -u "$GHOST_USERNAME" -h "localhost" -e "SELECT 1" &>/dev/null; then
        # Fresh image: root can authenticate via socket without a password yet.
        mysql -u "$GHOST_USERNAME" -h "localhost" \
            -e "ALTER USER '$GHOST_USERNAME'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
                CREATE USER IF NOT EXISTS '$GHOST_USERNAME'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
                ALTER USER '$GHOST_USERNAME'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '${GHOST_PASSWORD}';
                GRANT ALL PRIVILEGES ON *.* TO '$GHOST_USERNAME'@'127.0.0.1' WITH GRANT OPTION;
                FLUSH PRIVILEGES;"

        cat > "$PASSWORD_FILE" <<EOM
root_mysql_pass="${GHOST_PASSWORD}"
EOM
        chmod 600 "$PASSWORD_FILE"

        debian_sys_maint_mysql_pass=$(openssl rand -hex 24)
        mysql -u "$GHOST_USERNAME" -p"$GHOST_PASSWORD" \
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
        chmod 600 /etc/mysql/debian.cnf
    elif mysql -u "$GHOST_USERNAME" -p"$GHOST_PASSWORD" -h "localhost" -e "SELECT 1" &>/dev/null; then
        # Retry after a failed ghost install: MySQL already secured.
        cat > "$PASSWORD_FILE" <<EOM
root_mysql_pass="${GHOST_PASSWORD}"
EOM
        chmod 600 "$PASSWORD_FILE"
    else
        echo "MySQL root password is set but does not match ${PASSWORD_FILE}." >&2
        echo "Fix the password file or reset MySQL before re-running setup." >&2
        exit 1
    fi
else
    cat > "$PASSWORD_FILE" <<EOM
root_mysql_pass="${GHOST_PASSWORD}"
EOM
    chmod 600 "$PASSWORD_FILE"
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

# Ghost-CLI requires an empty install dir. The fail2ban placeholder under
# content/logs exists only so fail2ban can start on the image before setup.
systemctl stop fail2ban 2>/dev/null || true
find /var/www/ghost -mindepth 1 -delete
chown ghost-mgr: /var/www/ghost
chmod 775 /var/www/ghost

# Install Ghost
if ! sudo -iu ghost-mgr ghost install "$application_version" --auto \
  --db=mysql \
  --dbhost="$GHOST_HOST" \
  --dbport="$GHOST_PORT" \
  --dbname="$GHOST_DATABASE" \
  --dbuser="$GHOST_USERNAME" \
  --dbpass="$GHOST_PASSWORD" \
  --dir=/var/www/ghost \
  --start; then
    # Restore a log file so fail2ban can start again before the next retry.
    mkdir -p /var/www/ghost/content/logs
    chown -R ghost-mgr: /var/www/ghost
    install -o ghost-mgr -g ghost-mgr -m 0640 /dev/null \
        /var/www/ghost/content/logs/fail2ban-placeholder.log
    systemctl start fail2ban 2>/dev/null || true
    exit 1
fi

# Pick up Ghost's real log files for the ghost-* jails (not only the placeholder).
systemctl start fail2ban 2>/dev/null || systemctl restart fail2ban 2>/dev/null || true

# Final cleanup
cp /opt/ghost-setup/99-one-click /etc/update-motd.d/99-one-click
chmod 0755 /etc/update-motd.d/99-one-click

# Remove nginx default site
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx
