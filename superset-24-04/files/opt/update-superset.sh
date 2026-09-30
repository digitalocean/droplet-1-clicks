#!/bin/bash
# Rebuild the locally built image from the digest-pinned official base and
# apply metadata migrations. This does not move off the pinned Superset version.
set -euo pipefail

# shellcheck source=/dev/null
source /opt/superset/lib.sh

if [[ ! -s /etc/superset/superset.env ]]; then
  echo "Superset is not initialized. Run /var/lib/cloud/scripts/per-instance/001_onboot" >&2
  exit 1
fi

IMAGE="$(superset_image)"
echo "Rebuilding ${IMAGE} from /opt/superset/Dockerfile"

systemctl stop superset || true
docker rm -f superset >/dev/null 2>&1 || true

docker build --platform linux/amd64 -t "$IMAGE" /opt/superset

docker run --rm --entrypoint python3 "$IMAGE" -c \
  'import flask_caching, psycopg2, importlib.metadata as m
fc = m.version("Flask-Caching")
pg = m.version("psycopg2-binary")
assert fc == "2.3.1", fc
assert pg == "2.9.9", pg
print("pins ok", fc, pg)'

echo "Applying metadata migrations"
superset_run superset db upgrade

systemctl start superset
echo "Superset image rebuilt and service started."
