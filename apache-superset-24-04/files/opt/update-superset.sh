#!/bin/bash
# Update Apache Superset in the existing virtualenv.
# Usage: /opt/update-superset.sh [VERSION]
#   With no args, uses application_version from /var/lib/digitalocean/application.info
#   or prompts for latest pin from PyPI-style exact version.

set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  if [ -f /var/lib/digitalocean/application.info ]; then
    TARGET=$(sed -n 's/^application_version="\(.*\)"$/\1/p' /var/lib/digitalocean/application.info | tail -n1)
  fi
fi
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <VERSION>   e.g. $0 6.1.0" >&2
  exit 1
fi

echo "Updating Apache Superset to ${TARGET}..."
systemctl stop superset

sudo -u superset bash -c "
  set -euo pipefail
  cd /home/superset/superset-project
  . superset-env/bin/activate
  pip install --upgrade \"apache-superset==${TARGET}\" pillow psycopg2-binary gunicorn
  export SUPERSET_CONFIG_PATH=/home/superset/superset/superset_config.py
  superset db upgrade
  superset init
"

if [ -f /var/lib/digitalocean/application.info ]; then
  sed -i "s/^application_version=.*/application_version=\"${TARGET}\"/" /var/lib/digitalocean/application.info
fi

systemctl start superset
echo "Updated to ${TARGET} and restarted superset."
