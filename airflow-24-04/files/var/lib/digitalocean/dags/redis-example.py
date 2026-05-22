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
    # Uses 'redis_managed' connection:
    # - Points to local Redis (localhost:6379) by default
    # - Automatically switches to managed Valkey/Redis when DBaaS is attached
    # - Use 'redis_local' connection to explicitly target local Redis
    publish_task = RedisPublishOperator(
        task_id="publish_task",
        redis_conn_id="redis_managed",
        channel="your_channel",
        message="Start processing",
    )