# Apache Superset 1-Click Application

Deploy **Apache Superset** — an open-source data exploration and visualization platform — on Ubuntu 24.04 with PostgreSQL metadata storage and HTTPS via Caddy.

## What is Included

| Component | Purpose |
|-----------|---------|
| Apache Superset | BI / dashboard UI (version pinned in the image build) |
| PostgreSQL | Local metadata database (optional DigitalOcean Managed Postgres) |
| Caddy | Reverse proxy with shortlived Let's Encrypt TLS (HTTPS by IP) |
| UFW | SSH, HTTP, and HTTPS allowed |
| `superset` user | Non-root service account |
| `/opt/*-superset.sh` | Start, stop, restart, status, update, and domain helpers |

## System Requirements

Superset needs **at least 2 vCPUs**. Community guidance for a moderate instance is **8 GB RAM / 2 vCPUs**. Do not create 1-vCPU Droplets — first boot and the UI will often fail or become unreachable.

| Use case | Recommended size |
|----------|------------------|
| Minimum / light trial | 4 GB RAM / **2 vCPU** |
| Moderate production | 8 GB RAM / **2 vCPU** (matches Packer builder `s-2vcpu-8gb`) |
| Higher concurrency | 16 GB+ RAM / 4+ vCPU |

## Getting Started

1. **Deploy** this 1-Click from the DigitalOcean Marketplace with **≥ 2 vCPUs** (prefer ≥ 8 GB RAM).
2. Wait a few minutes for first-boot setup (`superset db upgrade`), then **SSH** in: `ssh root@your-droplet-ip`
3. Open the MOTD URL: **`https://your-droplet-public-ip`** (public IP from metadata — not a 10.x private address)
4. Sign in with user **`admin`** and the password from the MOTD (also in `/root/.digitalocean_passwords`).

### Custom domain

Point DNS at the Droplet, then run:

```bash
/opt/setup-superset-domain.sh
```

### Managed Database (optional)

Attach a DigitalOcean Managed PostgreSQL database when creating the Droplet. First boot will detect `/root/.digitalocean_dbaas_credentials` and reconfigure Superset automatically.

## Service Management

```bash
/opt/status-superset.sh
/opt/start-superset.sh
/opt/stop-superset.sh
/opt/restart-superset.sh
journalctl -u superset -f
journalctl -u caddy -f
```

| Path | Description |
|------|-------------|
| `/home/superset/superset-project` | Virtualenv + install |
| `/home/superset/superset/superset_config.py` | Superset config |
| `/root/.digitalocean_passwords` | Admin + DB + secret key |
| `/opt/setup-superset-domain.sh` | Custom domain TLS |
| `/opt/update-superset.sh` | Upgrade Superset in place |

## Updating

```bash
/opt/update-superset.sh <VERSION>
```

Example: `/opt/update-superset.sh 6.1.0`

To change the version baked into new Marketplace images, rebuild with an updated `application_version` in `template.json`.

## Security Notes

- Change the admin password after first login.
- Prefer a DigitalOcean Cloud Firewall limiting SSH to your IP.
- Superset listens on localhost only; Caddy terminates TLS on 80/443.

## Support and Resources

- [Apache Superset docs](https://superset.apache.org/docs/intro)
- [DigitalOcean Community](https://www.digitalocean.com/community)
