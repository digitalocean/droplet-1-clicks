#!/bin/bash

set -euo pipefail

ODOO_VERSION="${application_version:-18.0}"
ODOO_USER="odoo18"
ODOO_HOME="/opt/${ODOO_USER}"
ODOO_SOURCE="${ODOO_HOME}/${ODOO_USER}"
ODOO_VENV="${ODOO_HOME}/${ODOO_USER}-venv"

# Create the Odoo system user.
if ! id "$ODOO_USER" >/dev/null 2>&1; then
    useradd -m -d "$ODOO_HOME" -U -r -s /bin/bash "$ODOO_USER"
fi

# Add a PostgreSQL superuser for Odoo database management.
if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${ODOO_USER}'\"" | grep -q 1; then
    su - postgres -c "createuser -s ${ODOO_USER}"
fi

runuser -u "$ODOO_USER" -- bash -lc "
set -euo pipefail
cd '${ODOO_HOME}'
git clone https://www.github.com/odoo/odoo --depth 1 --branch '${ODOO_VERSION}' '${ODOO_USER}'
python3 -m venv '${ODOO_USER}-venv'
source '${ODOO_USER}-venv/bin/activate'
pip install --upgrade pip setuptools wheel
pip install -r '${ODOO_USER}/requirements.txt'
deactivate
mkdir -p '${ODOO_SOURCE}/custom-addons'
"

# Copy Odoo config and service files.
cp /etc/project-configs/odoo18.conf /etc/odoo18.conf
cp /etc/project-configs/odoo18.service /etc/systemd/system/odoo18.service

systemctl daemon-reload
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Odoo listens directly on 8069 in this image.
ufw limit ssh/tcp
ufw allow 8069/tcp
ufw --force enable
