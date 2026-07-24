#!/bin/bash
set -euo pipefail

# SUPERSET_VERSION must be set by the caller (011-superset.sh passes application_version)
VERSION="${SUPERSET_VERSION:?SUPERSET_VERSION is required}"

cd /home/superset
mkdir -p superset-project
cd superset-project
python3 -m venv superset-env
# shellcheck disable=SC1091
. superset-env/bin/activate
pip install --upgrade pip setuptools wheel
pip install pillow "apache-superset==${VERSION}" psycopg2-binary gunicorn
