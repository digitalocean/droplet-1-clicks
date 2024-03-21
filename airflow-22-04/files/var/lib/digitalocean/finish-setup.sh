#!/bin/bash -x

cd /home/airflow/airflow-project
source airflow-env/bin/activate
airflow db migrate
airflow users create --role Admin --username admin --email admin --firstname admin --lastname admin --password my-password