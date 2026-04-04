#!/bin/sh

# Create the airflow user
useradd --home-dir /home/airflow \
        --shell /bin/bash \
        --create-home \
        --system \
        airflow

# Setup the home directory
chown -R airflow: /home/airflow
chmod 755 /home/airflow

cd /home/airflow
sudo -u airflow mkdir airflow-project
cd airflow-project

# Copy the version-locked requirements file into the project
cp /var/lib/digitalocean/requirements.txt /home/airflow/airflow-project/requirements.txt
chown airflow:airflow /home/airflow/airflow-project/requirements.txt

# Build the constraints URL for the installed Python version.
# This pins every transitive dependency to versions tested by Apache,
# preventing the broken-entrypoint bug caused by unconstrained installs.
# AIRFLOW_VERSION comes from template.json's application_version variable
PYTHON_VERSION="$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${application_version}/constraints-${PYTHON_VERSION}.txt"

# Append the Airflow version to requirements.txt (single source of truth: template.json)
sed -i "s/^apache-airflow$/apache-airflow==${application_version}/" /home/airflow/airflow-project/requirements.txt

cat > /tmp/install_airflow.sh << EOF
        cd /home/airflow/airflow-project
        python3 -m venv airflow-env
        source airflow-env/bin/activate
        pip install --upgrade pip
        pip install -r /home/airflow/airflow-project/requirements.txt \
            --constraint "${CONSTRAINT_URL}"
EOF

chmod +x /tmp/install_airflow.sh
chown airflow:airflow /tmp/install_airflow.sh

sudo -s -u airflow /tmp/install_airflow.sh

rm -rvf /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/airflow \
      /etc/nginx/sites-enabled/airflow

# --- Set up local PostgreSQL for Airflow metadata ---
systemctl start postgresql
sudo -u postgres createuser airflow
sudo -u postgres createdb -O airflow airflow

# --- Enable local Redis ---
systemctl enable redis-server
systemctl start redis-server

# --- Generate Airflow config and configure local Postgres + LocalExecutor ---
cat > /tmp/setup_airflow_config.sh << 'SETUPEOF'
cd /home/airflow/airflow-project
source airflow-env/bin/activate
export AIRFLOW_HOME=/home/airflow/airflow

# Generate default config file
airflow version

# Use local PostgreSQL instead of SQLite (peer auth over unix socket)
sed -i 's|^sql_alchemy_conn\s*=.*|sql_alchemy_conn = postgresql+psycopg2:///airflow|' "$AIRFLOW_HOME/airflow.cfg"

# Use LocalExecutor instead of SequentialExecutor (enables parallel task execution)
sed -i 's|^executor\s*=.*|executor = LocalExecutor|' "$AIRFLOW_HOME/airflow.cfg"

# Initialize the Airflow schema in PostgreSQL
airflow db migrate
SETUPEOF

chmod +x /tmp/setup_airflow_config.sh
chown airflow:airflow /tmp/setup_airflow_config.sh
sudo -s -u airflow /tmp/setup_airflow_config.sh
