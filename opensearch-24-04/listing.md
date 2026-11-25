# OpenSearch 1-Click Application

Deploy [OpenSearch](https://opensearch.org/) and OpenSearch Dashboards on Ubuntu 24.04. The image installs a pinned OpenSearch release (from `application_version` in `template.json`) with TLS, the Security plugin, and a generated admin password on first boot.

## System Components

| Component | Details |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| OpenSearch | Version from `application_version` in `template.json` (currently `3.10.1`) |
| OpenSearch Dashboards | Version from `dashboards_version` (currently `3.10.0`; can lag OpenSearch by a patch) |
| Bundled JDK | Temurin (ships with the OpenSearch package; 3.10.1+ includes the Java4Shell fix) |
| UFW | Firewall (SSH 22, HTTP/HTTPS 80/443, OpenSearch 9200, Dashboards 5601) |

## System Requirements

**Minimum Droplet size: `s-2vcpu-4gb` (4 GB RAM / 2 vCPU).** The Packer builder uses this size.

| Use case | Recommended |
|----------|-------------|
| Marketplace minimum / tutorial | 4 GB RAM, 2 vCPU |
| Light production (single node) | 8 GB+ RAM, 4 vCPU |

## Getting Started

1. **Create a Droplet** from this 1-Click image (use at least **4 GB RAM / 2 vCPU**).
2. **Wait for first boot** — SSH is locked until `/var/lib/cloud/scripts/per-instance/001_onboot` finishes (apt install, TLS certs, `securityadmin`, services). SSH is unlocked even if OpenSearch setup fails.
3. **SSH in** and follow the MOTD for the `admin` password and HTTPS URLs.
4. **Verify** the API: `curl -k -u "admin:<password>" https://<droplet-ip>:9200`
5. Open **Dashboards** at `https://<droplet-ip>:5601` (self-signed TLS; browser warning expected).

**Security note:** Ports **9200** and **5601** are open to the internet with the generated admin password. Restrict source IPs in the cloud firewall for production, and rotate the password in `/root/.digitalocean_passwords` after first login.

## Managing OpenSearch

### Start, stop, restart, status

```bash
systemctl start opensearch
systemctl stop opensearch
systemctl restart opensearch
systemctl status opensearch

systemctl start opensearch-dashboards
systemctl stop opensearch-dashboards
systemctl restart opensearch-dashboards
systemctl status opensearch-dashboards
```

Logs: `/var/log/opensearch` and `journalctl -u opensearch` / `journalctl -u opensearch-dashboards`.

### Update

Marketplace Autoupdate rebuilds from pins in `template.json`. To change versions on a **new** image:

1. Set `application_version` (OpenSearch) and `dashboards_version` (Dashboards; may lag, e.g. `3.10.1` / `3.10.0`).
2. Rebuild with Packer (`packer build opensearch-24-04/template.json` or `-var application_version=3.10.1 -var dashboards_version=3.10.0`).

On an existing Droplet, re-enable the disabled apt sources shown in the MOTD, then `apt-get update && apt-get upgrade`. Prefer standing up a new Droplet from an updated snapshot for major upgrades.

## Data Locations

| Path | Purpose |
|------|---------|
| `/etc/opensearch/opensearch.yml` | OpenSearch config (written on first boot) |
| `/etc/opensearch/certs/` | TLS material (CA, node, admin) |
| `/etc/opensearch-dashboards/opensearch_dashboards.yml` | Dashboards config |
| `/var/lib/opensearch` | Index data |
| `/var/log/opensearch` | OpenSearch logs |
| `/root/.digitalocean_passwords` | Generated admin password |
| `/var/lib/digitalocean/application.info` | Marketplace application metadata / version |

## Support

- [OpenSearch documentation](https://opensearch.org/docs/)
- [DigitalOcean Community](https://www.digitalocean.com/community)
