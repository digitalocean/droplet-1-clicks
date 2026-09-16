# MariaDB

A DigitalOcean 1-Click Droplet running **MariaDB Server** on **Ubuntu 24.04 LTS**. On first SSH login as root, an interactive setup runs `mysql_secure_installation` to harden the database.

## System Components

| Component | Details |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| MariaDB Server | Latest GA from the official MariaDB apt repository |
| MariaDB Client | Matching client packages |
| UFW | Firewall (SSH 22, MySQL/MariaDB 3306) |

## Droplet size

This image is built on **`s-1vcpu-1gb`** (1 GB RAM). That is enough for light / development workloads. For production databases with larger datasets or higher concurrency, start at **2 GB RAM or more** and resize as needed.

## Getting Started

1. Create a Droplet from this image.
2. SSH in as **root**. On first login, follow the prompts to run MariaDB secure installation (set root password, remove anonymous users, disable remote root, remove test DB, reload privileges).
3. Connect locally with `mariadb -u root -p` (or `mysql -u root -p`).
4. For remote clients, open access carefully: create users with host restrictions, and keep UFW limited to trusted sources when possible (`ufw allow from <ip> to any port 3306`).

## Service Management

| Action | Command |
|--------|---------|
| Status | `systemctl status mariadb` |
| Start | `systemctl start mariadb` |
| Stop | `systemctl stop mariadb` |
| Restart | `systemctl restart mariadb` |
| Enable on boot | `systemctl enable mariadb` |

### Updates

MariaDB is installed from MariaDB’s **latest GA** apt repository (no package pin). Marketplace APT autoupdate rebuilds the image periodically so new majors (for example **13.0**) are picked up on the next image build.

On a running Droplet, update with:

```bash
sudo apt update && sudo apt upgrade
```

That applies OS updates and MariaDB packages available from the configured GA series on that image.
