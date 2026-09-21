# vybench-droplet: DigitalOcean 1-Click Droplet Appliance

Official Packer repository for building the **Vyogo Technologies 1-Click Droplet Appliance** for **ERPNext, CRM, HRMS & the Frappe App Ecosystem** powered by `vybench` and the [FPM catalog](https://fpm.vyogo.tech).

---

## Overview

This repository builds an official Ubuntu 24.04 LTS DigitalOcean Droplet snapshot configured to run production ERPNext instances immediately upon launch.

Key architectural features:
* **All-in-One Supervised Stack**: The `vybench` snap packages MariaDB 10.11+, Redis 7, Nginx, Python 3.14, Node.js 24, Yarn, wkhtmltopdf, and ERPNext as monitored daemons. No separate system-level service installations.
* **Stable Channel Enforcement**: The build installs exclusively from `--channel=stable` to ensure production reliability.
* **Instant App Additions via FPM**: Frappe apps are installed pre-compiled via `vybench.fpm` without compilation or memory spikes.
* **Automated First-Boot Provisioning**: A lightweight systemd oneshot service (`vybench-first-boot.service`) initializes the primary site at first boot, secures MariaDB root credentials, and writes administrative access details to `/root/.vybench_credentials`.
* **Out-of-the-Box Hardening**: UFW firewall restricts traffic to ports 22, 80, and 443; Fail2ban protects SSH; sensitive tokens and keys are sanitized before snapshot creation.
* **Full DO Marketplace Compliance**: Cleansed with `scripts/90-do-cleanup.sh` and validated against DigitalOcean's official `scripts/99-img-check.sh`.

---

## Directory Structure

```text
vybench-droplet/
├── .gitignore
├── Makefile                           # Convenience targets (init, validate, build)
├── README.md                          # Repository and build documentation
├── VENDOR-PORTAL.md                   # Paste-ready DO Vendor Portal listing copy
├── packer/
│   ├── plugins.pkr.hcl               # Packer digitalocean plugin requirements
│   ├── variables.pkr.hcl             # Variables (region, size, base_image, token)
│   └── vybench-droplet.pkr.hcl       # Main Packer build template
├── scripts/
│   ├── 01-system-setup.sh            # OS upgrades, UFW firewall, fail2ban
│   ├── 02-snap-install.sh            # Installs vybench snap (channel=stable)
│   ├── 03-snap-configure.sh          # Enables production mode & Nginx; asserts service health
│   ├── 04-first-boot-setup.sh        # Deploys first-boot script & systemd unit
│   ├── 05-motd-banner.sh             # Installs custom terminal login banner
│   ├── 90-do-cleanup.sh              # Marketplace sanitization (keys, logs, machine-id)
│   └── 99-img-check.sh               # Official DO Marketplace validation script
├── files/
│   ├── etc/update-motd.d/
│   │   └── 99-vybench-banner          # Branded login MOTD script
│   └── opt/vybench/
│       └── first_boot.sh              # First-boot site creation script
└── docs/assets/
    └── icon.png                       # 512x512 PNG icon for DO Vendor Portal
```

---

## Prerequisites

1. **Packer** (>= 1.8.0):
   ```bash
   brew install hashicorp/tap/packer
   # Or download binary from https://www.packer.io/downloads
   ```
2. **DigitalOcean Personal Access Token**:
   Generate a Read & Write token in your [DigitalOcean API Settings](https://cloud.digitalocean.com/account/api/tokens).
   Export the token to your environment:
   ```bash
   export DIGITALOCEAN_TOKEN="dop_v1_xxxxxxxxxxxxxxxxxxxxxxxx"
   ```

---

## Building the Image

### 1. Initialize Packer Plugins
Installs the required `digitalocean` Packer plugin:
```bash
make init
# or: packer init packer/
```

### 2. Validate Configuration
Checks HCL syntax and configuration validity:
```bash
make validate
# or: packer validate packer/
```

### 3. Build the Marketplace Snapshot
Launches an 8 GB Droplet (`s-4vcpu-8gb`) in `sgp1`, provisions all components, runs validation, powers down, and saves the snapshot:
```bash
make build
# or: packer build packer/
```

#### Customizing Build Parameters
You can override default variables on the command line:
```bash
# Build in a different region:
packer build -var 'region=nyc3' packer/

# Specify custom snapshot name:
packer build -var 'snapshot_name=vybench-v1-release' packer/
```

---

## Submitting to DigitalOcean Vendor Portal

1. Log in to the [DigitalOcean Vendor Portal](https://cloud.digitalocean.com/vendorportal).
2. Create or select your 1-Click Application: **ERPNext, CRM, HRMS & the Frappe App Ecosystem by Vyogo**.
3. Under **Images / Versions**, select the snapshot created by Packer (e.g. `vybench-droplet-20260921-xxxxxx`).
4. Copy the listing metadata, tagline, descriptions, and post-install instructions directly from [VENDOR-PORTAL.md](VENDOR-PORTAL.md).
5. Upload the logo icon located at `docs/assets/icon.png`.
6. Submit the version for DigitalOcean Marketplace review.

---

## Verification & Testing

To test your new snapshot before submitting to the portal:

1. In the DigitalOcean Cloud Console, create a new Droplet from the snapshot (under **Images** > **Snapshots**).
2. Choose at least **4 GB RAM** (`s-2vcpu-4gb`).
3. SSH into the Droplet:
   ```bash
   ssh root@<droplet-ip>
   ```
4. Confirm the following:
   * [ ] The branded MOTD banner appears with the app URL and quick commands.
   * [ ] `/root/.vybench_credentials` exists and contains randomized passwords.
   * [ ] `snap services vybench` shows all services (mariadb, redis, web, workers, scheduler, socketio, nginx) as `active`.
   * [ ] `ufw status verbose` shows only ports 22, 80, and 443 allowed.
   * [ ] ERPNext web login page is accessible at `http://<droplet-ip>`.
   * [ ] Logging in as `Administrator` with the generated password succeeds.

---

## Maintenance & Updates

When publishing an updated version:
1. Update `vybench` snap if needed (`snap refresh vybench --channel=stable`).
2. Run `make build` to create a fresh snapshot.
3. Submit the new snapshot ID as a new version in the DO Vendor Portal.

---

## Support & Ecosystem Links

* **Kubernetes 1-Click Operator**: [Vyogo Frappe Operator](https://vyogotech.github.io/frappe-operator/) ([DO Marketplace PR #594](https://github.com/digitalocean/marketplace-kubernetes/pull/594))
* **Vyogo Cloud Managed Hosting**: [https://console.vyogo.cloud](https://console.vyogo.cloud)
* **FPM App Catalog**: [https://fpm.vyogo.tech](https://fpm.vyogo.tech)
* **Vyogo Technologies**: [https://vyogo.tech](https://vyogo.tech)
* **Email Support**: [support@vyogo.tech](mailto:support@vyogo.tech)
