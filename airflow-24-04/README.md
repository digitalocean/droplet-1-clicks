# Airflow 1-Click

Deploy Apache Airflow on Ubuntu 24.04 with local PostgreSQL and Redis by default. Optionally attach DigitalOcean Managed Databases during Droplet creation for production-ready metadata storage and Celery task execution.

## Getting Started

1. Select the Airflow 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region
3. Optionally select **Add a Database** to attach Managed PostgreSQL and/or Managed Valkey/Redis (see below)
4. Create the Droplet and SSH in as `root`

On first boot, Airflow is configured automatically. Access the web UI at `http://your-droplet-ip` with:

- **Username:** `admin`
- **Password:** stored in `/root/.digitalocean_passwords`

## Using a DigitalOcean Managed Database (Optional)

When creating your Droplet, you can select **Add a Database** to provision Managed PostgreSQL and/or Managed Valkey/Redis alongside Airflow. Managed databases replace the local instances to better secure your data and give you easy backups, connection pools, and metrics. No manual DBaaS setup is required.

### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean provisions the selected database cluster(s) and passes connection credentials to your Droplet at first boot in `/root/.digitalocean_dbaas_credentials`.

During first-boot setup, the Droplet automatically:

**Managed PostgreSQL (metadata database):**

1. Waits for the PostgreSQL cluster to become available (this may take a few minutes)
2. Updates `sql_alchemy_conn` in `/home/airflow/airflow/airflow.cfg` to use the Managed Database over SSL
3. Re-runs Airflow database migrations against the managed cluster
4. Stops and disables the local PostgreSQL instance

**Managed Valkey/Redis (broker/keystore):**

1. Configures the `redis_managed` Airflow connection to point at the managed service with SSL enabled
2. Stops and disables the local Redis instance
3. If Managed PostgreSQL is also attached, switches Airflow to **CeleryExecutor** with the managed Redis broker and managed Postgres result backend, and starts the Celery worker service

If no Managed Database is added, Airflow uses local PostgreSQL (`localhost:5432`) and local Redis (`localhost:6379`). The local Redis password is stored in `/root/.digitalocean_passwords`.

### Security: Trusted Sources

Your Droplet is not automatically added to a Managed Database's trusted sources. For better security, add your Droplet's public IP address to each cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Modifying database settings later

- **Airflow metadata DB:** Update `sql_alchemy_conn` in `/home/airflow/airflow/airflow.cfg` and restart Airflow services
- **Celery broker/backend:** Update the `[celery]` section in `airflow.cfg` if using CeleryExecutor
- **Airflow connections:** Use `airflow connections` CLI or the Airflow UI to manage `redis_managed` and other connections
- **Password rotation:** If you change credentials in the control panel, update `airflow.cfg` and Airflow connections to match

## File Locations

- **Airflow home:** `/home/airflow/airflow`
- **Example DAGs:** `/home/airflow/airflow/dags`
- **Admin password:** `/root/.digitalocean_passwords`
- **Setup log:** `/var/log/one_click_setup.log`

