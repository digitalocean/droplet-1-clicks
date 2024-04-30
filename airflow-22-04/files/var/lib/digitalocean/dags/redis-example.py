from datetime import datetime

from airflow import DAG
from airflow.providers.redis.operators.redis_publish import RedisPublishOperator

default_args = {
    "start_date": datetime(2023, 5, 15),
    "max_active_runs": 1,
}

with DAG(
    dag_id="redis_example",
    default_args=default_args,
) as dag:
    # [START RedisPublishOperator_DAG]
    publish_task = RedisPublishOperator(
        task_id="publish_task",
        redis_conn_id="redis_conn",
        channel="your_channel",
        message="Start processing",
        dag=dag,
    )