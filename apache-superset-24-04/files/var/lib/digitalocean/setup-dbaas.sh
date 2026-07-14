#!/bin/bash -x

PG_CONFIGURED=false

if [ -f "/root/.digitalocean_dbaas_credentials" ]; then

    if grep -q '^db_protocol="postgresql"$' "/root/.digitalocean_dbaas_credentials"; then
        # grab all the data from the dbaas credentials file
        PG_HOST=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_PORT=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_USER=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_DB=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
        PG_PASS=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

        PG_URL="postgresql+psycopg2://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=require"

        # wait for db to become available
        echo -e "\nWaiting for your database to become available (this may take a few minutes)"
        while ! pg_isready -h "$PG_HOST" -p "$PG_PORT"; do
            printf .
            sleep 2
        done

        echo -e "\nDatabase available!\n"

        # Update Superset config to use managed Postgres
        cat > /home/superset/superset/superset_config.py <<CFGEOF
SECRET_KEY = "${SECRET_KEY}"

SQLALCHEMY_DATABASE_URI = "${PG_URL}"

WTF_CSRF_ENABLED = True
ENABLE_PROXY_FIX = True
CFGEOF
        chown superset:superset /home/superset/superset/superset_config.py

        # Stop local PostgreSQL since we're using managed database
        systemctl stop postgresql
        systemctl disable postgresql

        # Re-run migrations against the managed database
        sudo -u superset env PASSWORD="${PASSWORD}" bash /var/lib/digitalocean/finish-setup.sh

        PG_CONFIGURED=true
    fi
fi
