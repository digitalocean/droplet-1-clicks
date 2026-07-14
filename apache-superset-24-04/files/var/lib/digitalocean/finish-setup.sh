#!/bin/bash -x

cd /home/superset/superset-project
. superset-env/bin/activate
export SUPERSET_CONFIG_PATH=/home/superset/superset/superset_config.py

# PASSWORD is passed from 001_onboot / setup-dbaas (superset cannot read /root/.digitalocean_passwords)
if [ -z "${PASSWORD}" ]; then
    echo "PASSWORD is not set; cannot create admin user" >&2
    exit 1
fi

superset db upgrade

# create-admin fails if the user already exists (e.g. re-run after DBaaS switch)
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@example.com \
    --password "${PASSWORD}" || true

superset init
