
#!/bin/sh

# open port for clients
ufw allow 3000
ufw limit ssh/tcp
ufw --force enable

OPEN_WEBUI_IMAGE="ghcr.io/open-webui/open-webui:v${application_version}"

docker pull "${OPEN_WEBUI_IMAGE}"
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  -e DATABASE_POOL_SIZE=8 \
  -e DATABASE_SQLITE_PRAGMA_CACHE_SIZE=-2000 \
  -e DATABASE_SQLITE_PRAGMA_MMAP_SIZE=0 \
  --name open-webui \
  --restart always \
  "${OPEN_WEBUI_IMAGE}"
