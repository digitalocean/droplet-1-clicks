from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from datetime import datetime

def generate_logs():
    for i in range(1, 6):
        print(f"Logging message {i}")

with DAG(
    "remote_logging_test",
    start_date=datetime(2024, 4, 25),
    schedule_interval=None,
    catchup=False,
) as dag:

    log_task = PythonOperator(
        task_id="log_task",
        python_callable=generate_logs,
    )
