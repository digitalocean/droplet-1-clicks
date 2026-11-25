# OpenSearch 1-Click Droplet

Packer template for a DigitalOcean Marketplace 1-Click image that runs [OpenSearch](https://opensearch.org/) and OpenSearch Dashboards on Ubuntu 24.04.

## What's Included

- **OpenSearch** `application_version` and **Dashboards** `dashboards_version` in `template.json` (currently `3.10.1` / `3.10.0` — Dashboards can lag a patch)
- Bundled Temurin JDK from the OpenSearch package (3.10.1 addresses CVE-2026-114938 / Java4Shell)
- First-boot TLS (self-signed CA), Security plugin init via `securityadmin.sh`, random `admin` password
- **UFW** allowing SSH (22), HTTP/HTTPS (80/443), OpenSearch (9200), and Dashboards (5601)
- MOTD with credentials and version from `/var/lib/digitalocean/application.info`

## Droplet Size

Build and recommend **`s-2vcpu-4gb`** (4 GB RAM / 2 vCPU).

## Building

From the `droplet-1-clicks` repository root:

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"

# Packer 1.7+ DigitalOcean builder plugin
packer plugins install github.com/digitalocean/digitalocean

packer validate opensearch-24-04/template.json
packer build opensearch-24-04/template.json
```

`template.json` reads `do_api_token` from `DIGITALOCEAN_API_TOKEN` (same pattern as other 1-Clicks). No `-var do_api_token=…` is required.

Pin or override the app version:

```bash
packer build -var 'application_version=3.10.1' -var 'dashboards_version=3.10.0' opensearch-24-04/template.json
```

## How It Works

1. Packer waits for cloud-init, upgrades the base image, and copies `files/`.
2. `010-opensearch.sh` adds the OpenSearch/Dashboards apt repos and ensures `001_onboot` is executable.
3. `018-force-ssh-logout.sh` blocks SSH until per-instance setup finishes.
4. On first boot, `001_onboot` installs the pinned packages, generates PKCS#8 TLS certs, configures security, starts services, and unlocks SSH (including on failure via `EXIT` trap).

## Files

| Path | Purpose |
|------|---------|
| `template.json` | Packer build template (`application_version` / `dashboards_version` pins) |
| `scripts/010-opensearch.sh` | Apt repo setup |
| `files/var/lib/cloud/scripts/per-instance/001_onboot` | First-boot install and security setup |
| `files/etc/update-motd.d/99-one-click` | MOTD |
| `listing.md` | Marketplace catalog copy |
| `README.md` | This file |

## Smoke Test Checklist

After creating a Droplet from the snapshot:

- [ ] Packer build finished with no interactive/TTY hang
- [ ] After first boot, SSH is usable (ForceCommand cleared)
- [ ] `systemctl is-active opensearch` and `opensearch-dashboards` are active
- [ ] `curl -k -u "admin:<password>" https://127.0.0.1:9200` returns cluster info
- [ ] Dashboards responds on `https://<ip>:5601`
- [ ] MOTD shows the same version as `/var/lib/digitalocean/application.info`
- [ ] UFW allows 22, 80, 443, 9200, and 5601
