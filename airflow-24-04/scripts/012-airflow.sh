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
AIRFLOW_VERSION="3.1.8"
PYTHON_VERSION="$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

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
