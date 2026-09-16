# MariaDB (Ubuntu 24.04)

Packer template for a DigitalOcean Marketplace 1-Click image that installs the **latest MariaDB Server GA** from the official MariaDB apt repository on Ubuntu 24.04 LTS.

## What's Included

- **MariaDB Server / Client** via `mariadb_repo_setup --mariadb-server-version=latest` (no package pin) — Marketplace APT autoupdate rebuilds pick up new GA series (including future majors such as 13.0)
- First-login helper at `/opt/digitalocean_mariadb/setup_mariadb.sh` (`mysql_secure_installation`)
- **UFW** allowing SSH (22) and MariaDB (3306)
- **Ubuntu 24.04 LTS** base image

## Prereqs

* [make](https://www.gnu.org/software/make/)
* [Packer](https://www.packer.io/intro/index.html)
* `DIGITALOCEAN_API_TOKEN` set in the environment

## Building

From the `droplet-1-clicks` repository root:

```bash
export DIGITALOCEAN_API_TOKEN="your-token"

make validate-mariadb-24-04
make build-mariadb-24-04
```

Or with Packer directly:

```bash
packer validate mariadb-24-04/template.json
packer build mariadb-24-04/template.json
```

## Variables (`template.json`)

* `do_api_token` — API token; defaults to `DIGITALOCEAN_API_TOKEN`
* `image_name` — Snapshot name; default includes `mariadb-24-04-snapshot-` and a timestamp
* `application_name` — Marketplace application name (`MariaDB`)
* `application_version` — Default `Latest` (APT autoupdate passes an empty version and expects apt to install current GA). A concrete value such as `12.3.3` can be passed for a manual series pin.
* `apt_packages` — Base packages needed before the MariaDB install script

Override at build time with [Packer `-var`](https://developer.hashicorp.com/packer/docs/templates/hcl/variables).

## How It Works

1. Packer upgrades the system and installs apt prerequisites (`curl`, keyring helpers, etc.).
2. `scripts/010-mariadb.sh` runs MariaDB’s `mariadb_repo_setup` for **latest** GA, installs `mariadb-server` / `mariadb-client`, enables `mariadb.service`, and hooks first-login setup into `/root/.bashrc`.
3. `014-ufw-mysql.sh` enables UFW for SSH and port 3306.
4. `020-application-tag.sh` writes Marketplace metadata; `025-write-version.sh` sets `application_version` to the installed MariaDB version (matches autoupdate QA).
5. On first SSH login, `/opt/digitalocean_mariadb/setup_mariadb.sh` runs `mysql_secure_installation`, then restores a clean root `.bashrc`.

## Autoupdate

MariaDB is an **APT** autoupdate app (no `latestversion/mariadb.sh`). The service rebuilds on schedule with `application_version=` empty; this template installs current GA so QA (`mysqld` version vs `apt-cache policy` candidate) stays aligned when MariaDB publishes newer releases, including new majors.

## Droplet Size

Build size is **`s-1vcpu-1gb`**. Prefer **2 GB+** for production MariaDB workloads.
