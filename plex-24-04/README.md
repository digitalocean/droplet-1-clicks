# Plex Media Server 1-Click

Packer build template for the DigitalOcean Marketplace Plex Media Server 1-Click on Ubuntu 24.04 LTS.

## Build

```sh
export DIGITALOCEAN_API_TOKEN=dop_your-token
make validate-plex-24-04
make build-plex-24-04
```

Override the pinned Plex version at build time:

```sh
packer build \
  -var 'plex_version=1.43.2.10687-563d026ea' \
  -var 'application_version=1.43.2.10687-563d026ea' \
  plex-24-04/template.json
```

## Components

- Ubuntu 24.04 LTS
- Plex Media Server (`plexinc/pms-docker`, version pinned in `template.json`)
- Docker and Docker Compose
- NGINX reverse proxy (HTTP on port 80)
- UFW (SSH, HTTP/HTTPS, Plex port 32400)
- fail2ban

## Suggested Droplet size

4 GB RAM minimum (`s-2vcpu-4gb`), per the Akamai Plex deployment guide.

## Updating Plex on a Droplet

```sh
/opt/update-plex.sh
```

This fetches the latest versioned tag from Docker Hub, updates `docker-compose.yml`, pulls the image, and restarts the service.
