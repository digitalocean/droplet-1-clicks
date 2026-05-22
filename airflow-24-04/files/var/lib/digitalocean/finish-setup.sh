#!/bin/bash -x

cd /home/airflow/airflow-project
source airflow-env/bin/activate
airflow db migrate