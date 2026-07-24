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
  -var 'application_version=1.43.2.10687-563d026ea' \
  plex-24-04/template.json
```

## Components

- Ubuntu 24.04 LTS
- Plex Media Server (`plexinc/pms-docker`, version pinned as `application_version`)
- Docker and Docker Compose
- Caddy reverse proxy with Let's Encrypt shortlived TLS (ports 80/443)
- Setup-pending page until claim (prevents public claim takeover via reverse proxy)
- UFW (SSH, HTTP/HTTPS, Plex port 32400 after claim)
- fail2ban

## Suggested Droplet size

4 GB RAM minimum (`s-2vcpu-4gb`), per the Akamai Plex deployment guide.

## Updating Plex on a Droplet

```sh
/opt/update-plex.sh
```

This fetches the latest versioned tag from Docker Hub, updates `docker-compose.yml`, pulls the image, and restarts the service.

## First-time claim

HTTPS reverse-proxy to Plex is disabled until claim:

```sh
# Option A: claim token (also enables HTTPS)
sudo /opt/claim-plex.sh claim-XXXXXXXX

# Option B: SSH tunnel claim, then unlock HTTPS
sudo /opt/enable-plex-proxy.sh
# (refuses if Preferences.xml has no PlexOnlineToken; use --force only if needed)
```

## Custom domain TLS

After claim:

```sh
sudo /opt/setup-plex-domain.sh
```
