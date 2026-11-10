# MariaDB 1-Click Application

Deploy [MariaDB](https://mariadb.org/) Community Server on Ubuntu 24.04. This image installs a pinned MariaDB release from the official MariaDB apt repository, enables UFW for SSH and MySQL/MariaDB client access, and walks you through `mysql_secure_installation` on first SSH login.

## Software Included

| Package | Version | License |
|---------|---------|---------|
| MariaDB Server | 10.11.19 (from `application_version` in `template.json`) | GPL |
| Ubuntu | 24.04 LTS | — |
| UFW | enabled | — |

## System Components

- **MariaDB Server** — SQL database listening on port `3306`
- **mariadb client** — CLI tools (`mariadb`, `mariadb-admin`)
- **UFW** — allows SSH (`22`, rate-limited) and MariaDB (`3306`); does **not** open HTTP/HTTPS
- **First-login setup** — `/opt/digitalocean_mariadb/setup_mariadb.sh` runs `mysql_secure_installation`

## Getting Started After Deploying MariaDB

### 1. SSH in and finish secure setup

```bash
ssh root@YOUR_DROPLET_IP
```

On first login, the image runs `/opt/digitalocean_mariadb/setup_mariadb.sh`, which launches interactive **`mysql_secure_installation`**. Complete that wizard before using the database in production. Typical prompts:

- Set a **root password** (choose a strong password and store it somewhere safe)
- Remove anonymous users
- Disallow remote root login (recommended unless you have a specific need)
- Remove the test database
- Reload privilege tables

Until the wizard succeeds, it will run again on the next login. After it finishes successfully, the hook is removed from `/root/.bashrc`.

### 2. Where credentials live

This 1-Click does **not** pre-generate a root password file (there is no `/root/.digitalocean_password` by default).

| Credential | Location |
|------------|----------|
| MariaDB `root` password | The password **you set** during `mysql_secure_installation` — keep your own secure copy |
| SSH access | Your DigitalOcean SSH key or the root password emailed at Droplet create time |

If you need a written record on the Droplet after setup, create one yourself with restricted permissions, for example:

```bash
install -m 600 /dev/null /root/.digitalocean_password
# then store only what you need, e.g. root_mysql_pass=...
```

### 3. Log in to MariaDB

**On the Droplet** (after secure setup):

```bash
mariadb -u root -p
```

If unix_socket auth is still enabled for local root (common before or instead of a password), you can also use:

```bash
sudo mariadb
```

### 4. Create a database and application user

Prefer an application user instead of connecting as `root` from your apps:

```sql
CREATE DATABASE appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'appuser'@'%' IDENTIFIED BY 'choose_a_strong_password';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
```

For localhost-only apps, use `'appuser'@'localhost'` instead of `'%'`.

Connect as that user:

```bash
mariadb -u appuser -p -h 127.0.0.1 appdb
```

### 5. Firewall and remote access

UFW is enabled with:

| Port | Service |
|------|---------|
| `22/tcp` | SSH (rate-limited) |
| `3306/tcp` | MariaDB |

HTTP/HTTPS (`80` / `443`) are **not** opened — this image has no web UI.

Check rules:

```bash
ufw status
```

MariaDB packages typically listen on `127.0.0.1` until you allow remote clients. To accept connections from other hosts:

1. Edit the server config (commonly under `/etc/mysql/mariadb.conf.d/`) and set `bind-address = 0.0.0.0` (or a specific private IP).
2. Restart MariaDB: `systemctl restart mariadb`
3. Ensure the MariaDB user host matches the client (`'appuser'@'%'` or a specific IP).
4. Prefer a [DigitalOcean Cloud Firewall](https://docs.digitalocean.com/products/networking/firewalls/) that allows `3306` only from trusted sources — do not leave the database open to the whole internet.

From another machine (only after bind-address and grants allow it):

```bash
mariadb -u appuser -p -h YOUR_DROPLET_IP appdb
```

For a safer alternative without exposing `3306`, use an SSH tunnel:

```bash
ssh -L 3307:127.0.0.1:3306 root@YOUR_DROPLET_IP
mariadb -u appuser -p -h 127.0.0.1 -P 3307 appdb
```

### 6. Secure the install

- Finish **`mysql_secure_installation`** on first login and keep the root password private.
- Do not use the MariaDB `root` account from applications; create least-privilege users per database.
- Keep `Disallow root login remotely` enabled unless you have a controlled need.
- Restrict who can reach port `3306` with a Cloud Firewall (or rely on SSH tunnels and leave MariaDB bound to localhost).
- Keep the Droplet patched (`apt update` / `apt upgrade`) and rotate passwords if they may have been exposed.
- See [MariaDB security documentation](https://mariadb.com/kb/en/securing-mariadb/) for TLS, users, and hardening guidance.

## Managing MariaDB

### Start, stop, restart, status

```bash
systemctl start mariadb
systemctl stop mariadb
systemctl restart mariadb
systemctl status mariadb
```

### Update

Marketplace images are rebuilt from the pinned `application_version` in `template.json`. On an existing Droplet you can upgrade packages carefully with apt after reviewing MariaDB upgrade notes; for a clean Marketplace pin, create a new Droplet from the updated 1-Click snapshot and migrate data.

## Support

- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [DigitalOcean Marketplace MariaDB catalog](https://marketplace.digitalocean.com/apps/mariadb)
- [DigitalOcean Community](https://www.digitalocean.com/community)
