#!/bin/sh

# create the odoo user
sudo useradd -m -d /opt/odoo16 -U -r -s /bin/bash odoo16

# add a new postgresql user for our Odoo 16
sudo su - postgres -c "createuser -s odoo16"

sudo su - odoo16 <<EOL

git clone https://www.github.com/odoo/odoo --depth 1 --branch 16.0 odoo16
python3 -m venv odoo16-venv
source odoo16-venv/bin/activate
pip3 install wheel
pip3 install -r odoo16/requirements.txt
deactivate
mkdir /opt/odoo16/odoo16/custom-addons

exit

EOL


# Copy odoo config
cp /etc/project-configs/odoo16.conf /etc

# Copy odoo service config
cp /etc/project-configs/odoo16.service /etc/systemd/system

ufw allow 8069
