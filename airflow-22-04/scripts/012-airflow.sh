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

#sudo apt-get install -y python3-pip python3-venv # move to template!

cd /home/airflow
sudo -u airflow mkdir airflow-project
cd airflow-project

cat >> /tmp/install_airflow.sh << EOF
        cd /home/airflow/airflow-project
        python3 -m venv airflow-env
        source airflow-env/bin/activate
        pip install apache-airflow
        pip install apache-airflow-providers-postgres
EOF

chmod +x /tmp/install_airflow.sh
chown airflow:airflow /tmp/install_airflow.sh

sudo -s -u airflow /tmp/install_airflow.sh

rm -rvf /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/airflow \
      /etc/nginx/sites-enabled/airflow
