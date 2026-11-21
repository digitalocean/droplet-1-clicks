# MariaDB 24.04 1-Click

Packer builder for the DigitalOcean Marketplace MariaDB image on Ubuntu 24.04.

## Variables

| Variable | Purpose |
|----------|---------|
| `DIGITALOCEAN_API_TOKEN` | API token for Packer |
| `application_version` | Exact MariaDB version to pin (default in `template.json`: `10.11.19`) |

## Validate / build

```bash
export DIGITALOCEAN_API_TOKEN=...
make validate-mariadb-24-04
make build-mariadb-24-04
```

Or:

```bash
packer validate -var application_version=10.11.19 mariadb-24-04/template.json
packer build -var application_version=10.11.19 mariadb-24-04/template.json
```

Autoupdate / Packer must pass a non-empty `application_version`; the install script fails closed if it is unset.

## Layout

| Path | Role |
|------|------|
| `template.json` | Packer template (UFW via `common/scripts/014-ufw-mysql.sh`) |
| `scripts/010-mariadb.sh` | Official repo pin + install |
| `files/opt/digitalocean_mariadb/setup_mariadb.sh` | First-login `mysql_secure_installation` |
| `listing.md` | Marketplace / Vendor Portal catalog copy |

## Firewall

UFW allows **22** (SSH) and **3306** (MariaDB) only.
