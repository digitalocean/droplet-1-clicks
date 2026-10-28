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

# Ghost CLI's own "blog URL" prompt rejects a bare domain, and its error
# example is http://. If the user then enters http:// for a real domain, CLI
# keeps that URL after Let's Encrypt, and Ghost admin login fails with
# "incorrect origin" (expected http, received https). Ask here instead, and
# pass a normalized URL through --url so CLI does not prompt.

# Sets GHOST_URL and GHOST_USE_SSL. Domain (with or without a scheme) becomes
# https://. An IPv4 address becomes http:// and skips SSL.
normalize_ghost_site() {
    local input="$1"
    local host path octet

    input=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"

    while [[ "$input" == */ ]]; do
        input="${input%/}"
    done

    case "$input" in
        https://*) input="${input#https://}" ;;
        http://*)  input="${input#http://}" ;;
        //*)       input="${input#//}" ;;
    esac

    host="${input%%/*}"
    path="${input#"$host"}"
    if [ -n "$path" ]; then
        return 1
    fi
    if [[ "$host" == *@* || "$host" == *:* ]]; then
        return 1
    fi

    host="${host%.}"
    if [ -z "$host" ]; then
        return 1
    fi

    if [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local o1 o2 o3 o4
        IFS='.' read -r o1 o2 o3 o4 <<< "$host"
        for octet in "$o1" "$o2" "$o3" "$o4"; do
            if [ "$((10#$octet))" -gt 255 ]; then
                return 1
            fi
        done
        GHOST_URL="http://${host}"
        GHOST_USE_SSL=0
        return 0
    fi

    if [[ "$host" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
        GHOST_URL="https://${host}"
        GHOST_USE_SSL=1
        return 0
    fi

    return 1
}

echo "
Point an A record at this Droplet before continuing: $(tput setaf 6)${myip}$(tput sgr0)
DNS must already resolve, or the SSL certificate step will fail.

Enter your site address. Any of these is fine:
  example.com
  https://example.com
  http://example.com

A domain is stored as $(tput setaf 6)https://$(tput sgr0). If you do not have a domain yet, enter
$(tput setaf 6)${myip}$(tput sgr0) or $(tput setaf 6)http://${myip}$(tput sgr0). That skips SSL.
"

while true; do
    read -r -p "Site address: " site_input
    if normalize_ghost_site "$site_input"; then
        break
    fi
    echo "Enter a domain or IPv4 address, with or without http:// or https://."
    echo "Do not include a path or port. Examples: example.com, https://example.com, ${myip}"
done

ssl_email=""
if [ "$GHOST_USE_SSL" -eq 1 ]; then
    echo "Using ${GHOST_URL}. An SSL certificate will be requested for this address."
    while true; do
        read -r -p "Email for Let's Encrypt certificate notices: " ssl_email
        if [[ "$ssl_email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
            break
        fi
        echo "Enter an email address. It is used only for certificate expiry notices."
    done
else
    echo "Using ${GHOST_URL}. SSL is skipped for an IP address."
fi

source /var/lib/digitalocean/application.info

# A failed first run (DNS not ready yet) still writes the nginx site and the
# systemd unit. Ghost CLI then skips nginx on retry because that file exists,
# and it skips SSL whenever nginx was skipped. Remove this host's leftovers
# before installing again. The Ghost directory wipe below does not touch them.
ghost_host="${GHOST_URL#https://}"
ghost_host="${ghost_host#http://}"
ghost_host="${ghost_host%%/*}"
ghost_instance="ghost_${ghost_host//./-}"

systemctl stop "$ghost_instance" 2>/dev/null || true
systemctl disable "$ghost_instance" 2>/dev/null || true
rm -f "/lib/systemd/system/${ghost_instance}.service" \
    "/etc/systemd/system/${ghost_instance}.service"
systemctl daemon-reload 2>/dev/null || true
rm -f \
    "/etc/nginx/sites-available/${ghost_host}.conf" \
    "/etc/nginx/sites-enabled/${ghost_host}.conf" \
    "/etc/nginx/sites-available/${ghost_host}-ssl.conf" \
    "/etc/nginx/sites-enabled/${ghost_host}-ssl.conf"

# Ghost-CLI requires an empty install dir. The fail2ban placeholder under
# content/logs exists only so fail2ban can start on the image before setup.
systemctl stop fail2ban 2>/dev/null || true
find /var/www/ghost -mindepth 1 -delete
chown ghost-mgr: /var/www/ghost
chmod 775 /var/www/ghost

# Install Ghost. --url / --sslemail skip Ghost CLI's URL and email prompts.
ghost_install_args=(
    "$application_version"
    --auto
    --url "$GHOST_URL"
    --db=mysql
    --dbhost="$GHOST_HOST"
    --dbport="$GHOST_PORT"
    --dbname="$GHOST_DATABASE"
    --dbuser="$GHOST_USERNAME"
    --dbpass="$GHOST_PASSWORD"
    --dir=/var/www/ghost
    --start
)
if [ "$GHOST_USE_SSL" -eq 1 ]; then
    ghost_install_args+=(--sslemail "$ssl_email")
fi

if ! sudo -iu ghost-mgr ghost install "${ghost_install_args[@]}"; then
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
