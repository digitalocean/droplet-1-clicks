#!/bin/bash

set -euo pipefail

resolve_latest_odoo_version() {
    git ls-remote --heads https://github.com/odoo/odoo.git 'refs/heads/[0-9]*.0' | \
        awk -F/ '{print $NF}' | \
        sort -V | \
        tail -n 1
}

ODOO_REQUESTED_VERSION="${application_version:-latest}"
if [ "$ODOO_REQUESTED_VERSION" = "latest" ]; then
    ODOO_VERSION="$(resolve_latest_odoo_version)"
    if [ -z "$ODOO_VERSION" ]; then
        echo "Unable to resolve latest stable Odoo version from GitHub." >&2
        exit 1
    fi
    echo "Resolved latest stable Odoo version: ${ODOO_VERSION}"
else
    ODOO_VERSION="$ODOO_REQUESTED_VERSION"
fi

case "$ODOO_VERSION" in
    [0-9]*.0) ;;
    *)
        echo "Unsupported Odoo version: ${ODOO_VERSION}. Use stable branch names like 18.0 or 19.0." >&2
        exit 1
        ;;
esac

ODOO_SERIES="${ODOO_VERSION%%.*}"
ODOO_USER="odoo"
ODOO_HOME="/opt/${ODOO_USER}"
ODOO_SOURCE="${ODOO_HOME}/src"
ODOO_VENV="${ODOO_HOME}/venv"
ODOO_CUSTOM_ADDONS="${ODOO_HOME}/custom-addons"
ODOO_CONFIG="/etc/odoo.conf"
ODOO_SERVICE="${ODOO_USER}.service"

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
git clone https://github.com/odoo/odoo.git --depth 1 --branch '${ODOO_VERSION}' src
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r src/requirements.txt
deactivate
mkdir -p '${ODOO_CUSTOM_ADDONS}'
"

# Copy Odoo config and service files from templates.
python3 - "$ODOO_USER" "$ODOO_CONFIG" "$ODOO_HOME" "$ODOO_SOURCE" "$ODOO_VENV" "$ODOO_CUSTOM_ADDONS" <<'PY'
import sys

odoo_user, odoo_config, odoo_home, odoo_source, odoo_venv, odoo_custom_addons = sys.argv[1:]
replacements = {
    "__ODOO_USER__": odoo_user,
    "__ODOO_CONFIG__": odoo_config,
    "__ODOO_HOME__": odoo_home,
    "__ODOO_SOURCE__": odoo_source,
    "__ODOO_VENV__": odoo_venv,
    "__ODOO_CUSTOM_ADDONS__": odoo_custom_addons,
}

for src, dst in (
    ("/etc/project-configs/odoo.conf.template", odoo_config),
    ("/etc/project-configs/odoo.service.template", f"/etc/systemd/system/{odoo_user}.service"),
):
    with open(src, encoding="utf-8") as f:
        content = f.read()
    for old, new in replacements.items():
        content = content.replace(old, new)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(content)
PY

cat > /etc/default/odoo-1click <<EOF
ODOO_REQUESTED_VERSION="${ODOO_REQUESTED_VERSION}"
ODOO_VERSION="${ODOO_VERSION}"
ODOO_SERIES="${ODOO_SERIES}"
ODOO_USER="${ODOO_USER}"
ODOO_HOME="${ODOO_HOME}"
ODOO_SOURCE="${ODOO_SOURCE}"
ODOO_VENV="${ODOO_VENV}"
ODOO_CUSTOM_ADDONS="${ODOO_CUSTOM_ADDONS}"
ODOO_CONFIG="${ODOO_CONFIG}"
ODOO_SERVICE="${ODOO_SERVICE}"
EOF

build_date=$(date +%Y-%m-%d)
distro="$(lsb_release -s -i)"
distro_release="$(lsb_release -s -r)"
distro_codename="$(lsb_release -s -c)"
distro_arch="$(uname -m)"
install -d -m 0755 /var/lib/digitalocean
cat > /var/lib/digitalocean/application.info <<EOF
application_name="${application_name:-ODOO}"
build_date="${build_date}"
distro="${distro}"
distro_release="${distro_release}"
distro_codename="${distro_codename}"
distro_arch="${distro_arch}"
application_version="${ODOO_VERSION}"
EOF

systemctl daemon-reload
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Odoo listens directly on 8069 in this image.
ufw limit ssh/tcp
ufw allow 8069/tcp
ufw --force enable
