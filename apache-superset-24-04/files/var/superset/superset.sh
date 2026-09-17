#!/bin/bash

cd /home/superset/superset-project
. superset-env/bin/activate
export SUPERSET_CONFIG_PATH=/home/superset/superset/superset_config.py

exec gunicorn \
    -w 2 \
    -k gthread \
    --threads 4 \
    --timeout 120 \
    -b 127.0.0.1:8088 \
    "superset.app:create_app()"
