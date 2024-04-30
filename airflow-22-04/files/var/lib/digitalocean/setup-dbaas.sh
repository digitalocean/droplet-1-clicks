#!/bin/bash -x

if [ -f "/root/.digitalocean_dbaas_credentials" ]; then

     if grep -q '^db_protocol="postgresql"$' "/root/.digitalocean_dbaas_credentials"; then
     # grab all the data from the dbaas credentials file
     PG_HOST=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_PORT=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_USER=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_DB=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     PG_PASS=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

     PG_URL="postgresql+psycopg2://$PG_USER:$PG_PASS@$PG_HOST:$PG_PORT/$PG_DB"

     # wait for db to become available
     echo -e "\nWaiting for your database to become available (this may take a few minutes)"
     while ! pg_isready -h "$PG_HOST" -p "$PG_PORT"; do
          printf .
          sleep 2
     done

     echo -e "\nDatabase available!\n"

     sed -e "s|sqlite:////home/airflow/airflow/airflow.db|${PG_URL}|" -i /home/airflow/airflow/airflow.cfg

     sudo -s -u airflow /var/lib/digitalocean/finish-setup.sh #rerun airflow db migration to set new database
     fi

     if grep -q '^keystore_protocol="redis"$' "/root/.digitalocean_dbaas_credentials"; then
     # grab all the data from the dbaas credentials file
     REDIS_HOST=$(sed -n "s/^redis_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_PORT=$(sed -n "s/^redis_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_USER=$(sed -n "s/^redis_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_PASS=$(sed -n "s/^redis_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
     REDIS_CONN_ID=$(sed -n "s/^redis_conn_id=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

     cp /var/lib/digitalocean/dags/redis-example.py /home/airflow/airflow/dags
     chown airflow:airflow /home/airflow/airflow/dags/redis-example.py

     sudo -E -u airflow bash -c "
     cd /home/airflow/airflow-project &&
     source airflow-env/bin/activate &&
     airflow db init &&
     airflow connections add $REDIS_CONN_ID \
        --conn-type redis \
        --conn-login $REDIS_USER \
        --conn-port $REDIS_PORT \
        --conn-password $REDIS_PASS \
        --conn-host $REDIS_HOST \
        --conn-extra '{\"ssl\":\"true\"}'"
     fi
fi