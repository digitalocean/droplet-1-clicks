#!/bin/bash -x

PG_CONFIGURED=false
CELERY_EXECUTOR_ENABLED=false

if [ -f "/root/.digitalocean_dbaas_credentials" ]; then

     if grep -q '^db_protocol="postgresql"$' "/root/.digitalocean_dbaas_credentials"; then
     # grab all the data from the dbaas credentials file
     PG_HOST=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_PORT=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_USER=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_DB=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_PASS=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

     PG_URL="postgresql+psycopg2://$PG_USER:$PG_PASS@$PG_HOST:$PG_PORT/$PG_DB?sslmode=require"

     # wait for db to become available
     echo -e "\nWaiting for your database to become available (this may take a few minutes)"
     while ! pg_isready -h "$PG_HOST" -p "$PG_PORT"; do
          printf .
          sleep 2
     done

     echo -e "\nDatabase available!\n"

     sed -i "s|^sql_alchemy_conn\s*=.*|sql_alchemy_conn = ${PG_URL}|" /home/airflow/airflow/airflow.cfg

     # Stop local PostgreSQL since we're using managed database
     systemctl stop postgresql
     systemctl disable postgresql

     sudo -s -u airflow /var/lib/digitalocean/finish-setup.sh #rerun airflow db migration to set new database

     PG_CONFIGURED=true
     fi

     if grep -q '^keystore_protocol="redis' "/root/.digitalocean_dbaas_credentials"; then
     # grab all the data from the dbaas credentials file
     REDIS_HOST=$(sed -n "s/^redis_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_PORT=$(sed -n "s/^redis_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_USER=$(sed -n "s/^redis_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_PASS=$(sed -n "s/^redis_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_CONN_ID=$(sed -n "s/^redis_conn_id=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

     # Add managed Redis/Valkey connection
     sudo -u airflow AIRFLOW_HOME=/home/airflow/airflow bash -c "
     cd /home/airflow/airflow-project &&
     source airflow-env/bin/activate &&
     airflow connections delete redis_managed 2>/dev/null || true &&
     airflow connections add redis_managed \
        --conn-type redis \
        --conn-login $REDIS_USER \
        --conn-port $REDIS_PORT \
        --conn-password $REDIS_PASS \
        --conn-host $REDIS_HOST \
        --conn-extra '{\"ssl\":\"true\"}'"

     # Stop local Redis since we're using managed Redis
     systemctl stop redis-server
     systemctl disable redis-server

     # If managed Postgres is also attached, switch to CeleryExecutor
     if [ "$PG_CONFIGURED" = true ]; then
          BROKER_URL="rediss://${REDIS_USER}:${REDIS_PASS}@${REDIS_HOST}:${REDIS_PORT}/0"
          RESULT_BACKEND="db+postgresql://${PG_USER}:${PG_PASS}@${PG_HOST}:${PG_PORT}/${PG_DB}?sslmode=require"

          sed -i "s|^executor\s*=.*|executor = CeleryExecutor|" /home/airflow/airflow/airflow.cfg

          # Add [celery] section — update if it exists, append if it doesn't
          if grep -q '^\[celery\]' /home/airflow/airflow/airflow.cfg; then
               sed -i "s|^broker_url\s*=.*|broker_url = ${BROKER_URL}|" /home/airflow/airflow/airflow.cfg
               sed -i "s|^result_backend\s*=.*|result_backend = ${RESULT_BACKEND}|" /home/airflow/airflow/airflow.cfg
          else
               cat >> /home/airflow/airflow/airflow.cfg <<CELERYEOF

[celery]
broker_url = ${BROKER_URL}
result_backend = ${RESULT_BACKEND}
CELERYEOF
          fi

          CELERY_EXECUTOR_ENABLED=true
          echo "CeleryExecutor configured with managed Postgres + Redis"
     fi
     fi
fi