
#!/bin/sh

# open port for clients
ufw allow 3000
ufw limit ssh/tcp
ufw --force enable

docker pull ghcr.io/open-webui/open-webui:v0.10.2
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  -e DATABASE_POOL_SIZE=8 \
  -e DATABASE_SQLITE_PRAGMA_CACHE_SIZE=-2000 \
  -e DATABASE_SQLITE_PRAGMA_MMAP_SIZE=0 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:v0.10.2
