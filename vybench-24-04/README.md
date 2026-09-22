# vybench-droplet: DigitalOcean 1-Click Droplet Appliance

Official Packer repository for building the **Vyogo Technologies 1-Click Droplet Appliance** for **ERPNext, CRM, HRMS & the Frappe App Ecosystem** powered by `vybench` and the [FPM catalog](https://fpm.vyogo.tech).

---

## Overview

This repository builds an official Ubuntu 24.04 LTS DigitalOcean Droplet snapshot configured to run production ERPNext instances immediately upon launch.

Key architectural features:
* **All-in-One Supervised Stack**: The `vybench` snap packages MariaDB 10.11+, Redis 7, Nginx, Python 3.14, Node.js 24, Yarn, wkhtmltopdf, and ERPNext as monitored daemons. No separate system-level service installations.
* **Stable Channel Enforcement**: The build installs exclusively from `--channel=stable` to ensure production reliability and automatic security/bug-fix updates via `snap refresh`.
* **Optional Block Storage for persistent data**: `vybench-volume.service` runs before the database starts. If a DigitalOcean Block Storage volume is attached (at creation or later, followed by a reboot), it moves the database/sites/uploads onto it and bind-mounts it over the snap's data path -- so the Droplet's own disk can be resized/rebuilt without losing data. With no volume attached, everything works exactly as before, on the Droplet's local disk.
* **Instant App Additions via FPM**: Frappe apps are installed pre-compiled via `vybench.fpm` without compilation or memory spikes.
* **Automated First-Boot Provisioning**: A lightweight systemd oneshot service (`vybench-first-boot.service`) initializes the primary site at first boot, secures MariaDB root credentials, and writes administrative access details to `/root/.vybench_credentials`.
* **Out-of-the-Box Hardening**: UFW firewall restricts traffic to ports 22, 80, and 443; Fail2ban protects SSH; sensitive tokens and keys are sanitized before snapshot creation.
* **Full DO Marketplace Compliance**: Cleansed with `scripts/90-do-cleanup.sh` and validated against DigitalOcean's official `scripts/99-img-check.sh`.

---

## Directory Structure

This image lives in the [digitalocean/droplet-1-clicks](https://github.com/digitalocean/droplet-1-clicks) layout. Build from the repository root.

```text
vybench-24-04/
├── README.md
├── listing.md                         # Paste-ready Vendor Portal copy
├── template.json                      # Packer template
├── scripts/
│   └── 010-vybench.sh                 # snap install (stable), firewall, services, volume ordering
└── files/
    ├── etc/systemd/system/
    │   ├── vybench-first-boot.service
    │   └── vybench-volume.service     # Binds a Block Storage volume, if attached, before mariadb starts
    ├── etc/update-motd.d/
    │   └── 99-one-click               # Login banner (shows persistent-storage status)
    └── opt/vybench/
        ├── first_boot.sh              # Creates the first ERPNext site
        └── mount_volume.sh            # Detects/formats/bind-mounts an attached Block Storage volume
```

Shared Marketplace cleanup lives in `common/scripts/` (`900-cleanup.sh`, image check) and is wired from `template.json`.

---

## Prerequisites

1. **Packer** (>= 1.8.0):
   ```bash
   brew install hashicorp/tap/packer
   ```
2. **DigitalOcean Personal Access Token** with read and write access:
   ```bash
   export DIGITALOCEAN_API_TOKEN="your-token"
   ```

---

## Building the Image

From the repository root, with `DIGITALOCEAN_API_TOKEN` set:

```bash
make validate-vybench-24-04
make build-vybench-24-04
```

That launches an 8 GB Droplet (`s-4vcpu-8gb`) in `sgp1`, installs `vybench` from the stable channel, powers it down, and saves a snapshot named `vybench-24-04-snapshot-<timestamp>`.

The same commands directly:

```bash
packer validate vybench-24-04/template.json
packer build vybench-24-04/template.json
```

---

## Submitting to DigitalOcean Vendor Portal

1. Log in to the [DigitalOcean Vendor Portal](https://cloud.digitalocean.com/vendorportal).
2. Create or select your 1-Click Application: **ERPNext, CRM, HRMS & the Frappe App Ecosystem by Vyogo**.
3. Under **Images / Versions**, select the snapshot created by Packer (`vybench-24-04-snapshot-<timestamp>`).
4. Copy the listing metadata, tagline, descriptions, and post-install instructions from [listing.md](listing.md).
5. Upload the 512×512 logo. The listing points at `docs/assets/icon.png` in the vybench-droplet repo (`https://raw.githubusercontent.com/vyogotech/frappe-operator/release/docs/assets/icon.png`).
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
   * [ ] The branded MOTD banner appears with the app URL, `sudo vybench.tui`, and quick commands.
   * [ ] `/root/.vybench_credentials` exists and contains randomized passwords.
   * [ ] `snap services vybench` shows all services (mariadb, redis, web, workers, scheduler, socketio, nginx) as `active`.
   * [ ] `ufw status verbose` shows only ports 22, 80, and 443 allowed.
   * [ ] ERPNext web login page is accessible at `http://<droplet-ip>`.
   * [ ] Logging in as `Administrator` with the generated password succeeds.
   * [ ] (Optional) Attach a Block Storage volume before creating the Droplet: after boot, `mount | grep vybench/common` shows a bind mount, and `/var/snap/vybench/common/.vybench-on-volume` exists.
   * [ ] `snap refresh vybench` and `snap revert vybench` both complete cleanly and the site keeps serving HTTP 200 throughout.

---

## Maintenance & Updates

When publishing an updated version:
1. Confirm `snap info vybench` shows the stable revision you want baked in.
2. From the repo root, run `make build-vybench-24-04` to create a fresh snapshot. The image install does not refresh after bake, so a new snapshot is how new Droplets pick up a newer stable snap.
3. Submit the new snapshot ID as a new version in the DO Vendor Portal.

---

## Support & Ecosystem Links

* **Kubernetes 1-Click Operator**: [Vyogo Frappe Operator](https://vyogotech.github.io/frappe-operator/) ([DO Marketplace PR #594](https://github.com/digitalocean/marketplace-kubernetes/pull/594))
* **Vyogo Cloud Managed Hosting**: [https://console.vyogo.cloud](https://console.vyogo.cloud)
* **FPM App Catalog**: [https://fpm.vyogo.tech](https://fpm.vyogo.tech)
* **Vyogo Technologies**: [https://vyogo.tech](https://vyogo.tech)
* **Email Support**: [support@vyogo.tech](mailto:support@vyogo.tech)
