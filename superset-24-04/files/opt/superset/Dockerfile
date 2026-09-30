# Apache Superset 6.1.0 lean image, digest-pinned.
# Tag 6.1.0 multi-arch manifest list:
#   sha256:16b50bbef6648912a79e3293d418fefa743ce555d36c5af6b85d859119ed7f88
# linux/amd64 manifest used below (DigitalOcean Droplets are x86_64):
#   sha256:8b0426ef41beba328549e45371ea181f1c6761a871f167565cdab33c76057fe1
FROM apache/superset@sha256:8b0426ef41beba328549e45371ea181f1c6761a871f167565cdab33c76057fe1

USER root

# Superset 6.1.0 pins Flask-Caching in requirements/base.txt and psycopg2-binary
# in the postgres extra. The published lean image does not include a database
# driver. Install these exact wheels and do not resolve newer dependencies.
RUN . /app/.venv/bin/activate && \
    uv pip install --no-cache --no-deps \
      "Flask-Caching==2.3.1" \
      "psycopg2-binary==2.9.9"

USER superset

CMD ["/app/docker/entrypoints/run-server.sh"]
