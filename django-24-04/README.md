# Django 1-Click

Deploy Django on Ubuntu 24.04 with PostgreSQL, Gunicorn, and Nginx. By default, PostgreSQL runs locally. You can optionally attach a DigitalOcean Managed PostgreSQL database during deployment.

## Getting Started

1. Select the Django 1-Click from the DigitalOcean Marketplace
2. Choose a Droplet size and region
3. Optionally select **Add a Database** to provision a Managed PostgreSQL database (see below)
4. Create the Droplet and SSH in as `root`

On first boot, a sample Django project is created and started automatically.

**Django admin:**

- **URL:** `http://your-droplet-ip/admin`
- **Username:** `django` (see `/root/.digitalocean_passwords`)
- **Password:** stored in `/root/.digitalocean_passwords`

## Using a DigitalOcean Managed Database (Optional)

When creating your Django Droplet, you can select **Add a Database** to provision a DigitalOcean Managed PostgreSQL database at the same time. A managed database replaces the local PostgreSQL instance to better secure your data and gives you easy backups, connection pools, and metrics. No manual DBaaS setup is required.

### What happens when you add a database

When you choose this option during Droplet creation, DigitalOcean:

1. Provisions a Managed PostgreSQL cluster in the same region as your Droplet
2. Passes connection credentials to your Droplet at first boot in `/root/.digitalocean_dbaas_credentials`

During first-boot setup, the Droplet automatically:

1. Waits for the PostgreSQL cluster to become available (this may take a few minutes)
2. Creates a dedicated `django` database user and `django` database on the managed cluster
3. Updates `/home/django/django_project/django_project/settings.py` with the managed host and port
4. Runs Django migrations against the managed database
5. Stops and disables the local PostgreSQL instance

Database credentials for the Django application are stored in `/root/.digitalocean_passwords` (`DJANGO_POSTGRESS_PASS`).

### Security: Trusted Sources

Your Droplet is not automatically added to the Managed Database's trusted sources. For better security, add your Droplet's public IP address to the database cluster's **Trusted Sources** in the [DigitalOcean control panel](https://cloud.digitalocean.com/databases):

1. Open your database cluster in the control panel
2. Go to **Settings** → **Trusted Sources**
3. Add your Droplet's public IP address

### Modifying database settings later

- **Django settings:** Update database configuration in `/home/django/django_project/django_project/settings.py`
- **Application password:** `/root/.digitalocean_passwords` (`DJANGO_POSTGRESS_PASS`)
- **Password rotation:** If you change the database password in the control panel, update `settings.py` and `/root/.digitalocean_passwords` to match

## File Locations

- **Django project:** `/home/django/django_project`
- **Passwords and keys:** `/root/.digitalocean_passwords`
- **Setup log:** `/var/log/one_click_setup.log`

# Get your code on here

Clone your Django code onto the droplet, anywhere you like. Note: If you're not using a source control, you can directly upload the files to your droplet using SFTP.

You can try to reuse this project, located in `/home/django/django_project`, or start fresh in a new location and edit Gunicorn's configuration to point to it at `/etc/systemd/system/gunicorn.service`. You can also change how nginx is routing traffic by editing `/etc/nginx/sites-enabled/default`

Cd into the directory where your Django code lives, and install any dependencies. (For example, if you have a `requirements.txt` file, run `pip install -r requirements.txt`.)

That's it! Whenever you make code changes, reload Gunicorn like so:

```shell
PID=$(systemctl show --value -p MainPID gunicorn.service) && kill -HUP $PID
```

# Play in the admin area

The standard Django admin area is accessible at `/admin`. The login and password are stored in the `DJANGO_USER*` values you see when you call `cat /root/.digitalocean_passwords` while logged in over SSH.

# Get production-ready

There's a lot you'll want to do to make sure you're production-ready. Here are the popular things that people will do.

**Firewall:** Review your firewall settings by calling sudo ufw status, and make any changes you need. By default, only SSH/SFTP (port 22), HTTP (port 80), and HTTPS (port 443) are open. You can also disable this firewall by calling sudo ufw disable and use a DigitalOcean cloud firewall instead, if you like (they're free).

**Domain:** Register a custom domain

**Storage:** You can mount a volume (up to 16TB) to this server to expand the filesystem, provision a database cluster (that runs MySQL, Redis, or PostgreSQL), or use a Space, which is an S3-compatible bucket for storing objects.

