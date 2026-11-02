#!/bin/bash

superset_image() {
  if [[ ! -s /etc/superset/image-ref ]]; then
    echo "Missing /etc/superset/image-ref. Re-run the image install." >&2
    return 1
  fi
  tr -d '[:space:]' < /etc/superset/image-ref
}

superset_run() {
  local image
  image="$(superset_image)"
  docker run --rm \
    --add-host=host.docker.internal:host-gateway \
    --env-file /etc/superset/superset.env \
    -v /var/lib/superset/home:/app/superset_home \
    -v /etc/superset/superset_config.py:/etc/superset/superset_config.py:ro \
    "$image" \
    "$@"
}

postgres_uri() {
  python3 - "$@" <<'PY'
import sys
import urllib.parse

user, password, host, port, database, sslmode = sys.argv[1:7]
auth = urllib.parse.quote(user, safe="") + ":" + urllib.parse.quote(password, safe="")
uri = f"postgresql+psycopg2://{auth}@{host}:{port}/{database}"
if sslmode:
    uri += "?sslmode=" + urllib.parse.quote(sslmode, safe="")
print(uri)
PY
}

chown_superset_home() {
  local uid gid image
  image="$(superset_image)"
  uid="$(docker run --rm --entrypoint /usr/bin/id "$image" -u)"
  gid="$(docker run --rm --entrypoint /usr/bin/id "$image" -g)"
  chown -R "${uid}:${gid}" /var/lib/superset/home
}

ensure_superset_container() {
  if docker container inspect superset >/dev/null 2>&1; then
    return 0
  fi
  if [[ ! -s /etc/superset/superset.env ]]; then
    echo "Superset is not initialized. Run /var/lib/cloud/scripts/per-instance/001_onboot" >&2
    return 1
  fi
  local image
  image="$(superset_image)"
  docker create \
    --name superset \
    --restart no \
    -p 127.0.0.1:8088:8088 \
    --add-host=host.docker.internal:host-gateway \
    --env-file /etc/superset/superset.env \
    -v /var/lib/superset/home:/app/superset_home \
    -v /etc/superset/superset_config.py:/etc/superset/superset_config.py:ro \
    "$image"
}
