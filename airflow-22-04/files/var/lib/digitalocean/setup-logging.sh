#!/bin/bash -x

if [ -f "/root/.digitalocean_spaces_credentials" ] && grep -q '^spaces_conn_type="aws"$' "/root/.digitalocean_spaces_credentials"; then
     # grab all the data from the dbaas credentials file
     S3_HOST=$(sed -n "s/^spaces_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_spaces_credentials)
     S3_BUCKET=$(sed -n "s/^spaces_bucket_name=\"\(.*\)\"$/\1/p" /root/.digitalocean_spaces_credentials)
     S3_LOGIN=$(sed -n "s/^spaces_access_key_id=\"\(.*\)\"$/\1/p" /root/.digitalocean_spaces_credentials)
     S3_PASSWORD=$(sed -n "s/^spaces_secret_key=\"\(.*\)\"$/\1/p" /root/.digitalocean_spaces_credentials)
     S3_REGION=$(sed -n "s/^spaces_region=\"\(.*\)\"$/\1/p" /root/.digitalocean_spaces_credentials)
     SPACES_CONN_ID=$(sed -n "s/^spaces_conn_id=\"\(.*\)\"$/\1/p" /root/.digitalocean_spaces_credentials)

     sed -i -e "s/^remote_logging = False/remote_logging = True/" \
          -e "s/^remote_log_conn_id =/remote_log_conn_id = $SPACES_CONN_ID/" \
          -e "s|^remote_base_log_folder =.*|remote_base_log_folder = s3://$S3_BUCKET/logs|" \
          /home/airflow/airflow/airflow.cfg

     cp /var/lib/digitalocean/dags/remote-logging-example.py /home/airflow/airflow/dags
     chown airflow:airflow /home/airflow/airflow/dags/remote-logging-example.py

     CONN_EXTRA=$(jq -n --arg S3_REGION "$S3_REGION" --arg S3_HOST "$S3_HOST" '{"ACL":"private", "region_name":$S3_REGION, "host":$S3_HOST}')
     CONN=\'$CONN_EXTRA\'

     sudo -E -u airflow bash -c "
     cd /home/airflow/airflow-project &&
     source airflow-env/bin/activate &&
     airflow connections add $SPACES_CONN_ID \
     --conn-type aws \
     --conn-login "$S3_LOGIN" \
     --conn-password "$S3_PASSWORD" \
     --conn-extra $CONN"
fi