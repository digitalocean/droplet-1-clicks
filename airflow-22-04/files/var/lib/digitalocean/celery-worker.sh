#!/bin/bash
source /home/airflow/airflow-project/airflow-env/bin/activate
airflow celery worker
