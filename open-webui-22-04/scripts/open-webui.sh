
#!/bin/sh

# open port for clients
ufw allow 3000
ufw limit ssh/tcp
ufw --force enable

# Get the latest version of open-webui
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main