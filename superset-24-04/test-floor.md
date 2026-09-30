#### PR Description

- Add the Ubuntu 24.04 Apache Superset 6.1.0 1-Click: digest-pinned Docker image, Caddy shortlived HTTPS, and first-boot admin password
- Store metadata on local PostgreSQL 16, or on attached Managed Postgres after a bounded `pg_isready` wait, with `sslmode=require`
- Copy an already-migrated local metadata database into Managed Postgres before the switch. A failed copy stays on local PostgreSQL and does not stop it
- Point metadata at the managed admin user, and point **Source** at `superset_reader` on database `superset_source` on that cluster. Without Managed Postgres, **Source** stays on local `superset_source`
- On timeout, incomplete credentials, or a bad port, write `local` and exit 0 so first boot still starts Superset. A missing `/etc/superset/superset.env` still exits non-zero
- Delete `/etc/superset/dbaas.vars` after the URI is written. Restart PostgreSQL when `listen_addresses` changes, and refresh the Caddy site address when the metadata IP changes
- Pin Flask-Caching 2.3.1 and psycopg2-binary 2.9.9, and fail the image build unless `application_version` and the Dockerfile digest are the same release

Jira: https://do-internal.atlassian.net/browse/MP-8459

#### PR Checklist

Here are some basic guidelines:

Submitter checklist
- Changes are covered by tests
- Proof of testing:
  - Local script validation:
    ```
    $ bash -n superset-24-04/files/var/lib/cloud/scripts/per-instance/001_onboot
    $ bash -n superset-24-04/files/var/lib/digitalocean/setup-dbaas.sh
    $ bash -n superset-24-04/files/var/lib/digitalocean/finish-setup.sh
    $ bash -n superset-24-04/files/opt/bootstrap-superset.sh
    $ bash -n superset-24-04/scripts/010-superset.sh
    ```
## 1 · Local metadata database

Droplet A · Create Droplet A with no database attached. This proves Superset boots on local PostgreSQL and that SSH unlocks.

- [ ] Create Droplet A from the snapshot. Do not select Add a Database.
- [ ] MOTD shows `https://<public-ip>`, user `admin`, and a password. That password matches `/etc/superset/admin.password`.
- [ ] `systemctl is-active postgresql` prints `active`. `/root/.digitalocean_dbaas_credentials` does not exist. `/var/lib/digitalocean/superset-metadata-db` contains `local`.
- [ ] MOTD says metadata is local PostgreSQL 16 (database `superset`). Source is `superset_source` with reader role `superset_reader`.
- [ ] `ufw status` allows 22, 80, and 443, and does not allow 8088. Port 5432 is allowed on `docker0` only.
- [ ] `listen_addresses` in `/etc/postgresql/16/main/conf.d/superset.conf` is the Docker bridge gateway, not `*`.
- [ ] Sign in as `admin` with the MOTD password. Superset home loads. Sign out and sign in once more.

## 2 · Managed PostgreSQL

Droplet B · Create Droplet B with Add a Database → PostgreSQL, same region. Add Droplet B’s public IP to the cluster’s Trusted Sources. Metadata uses the attached database as the cluster admin. **Source** uses `superset_reader` on database `superset_source` on that cluster.

- [ ] Create Droplet B with Managed PostgreSQL. Confirm `/root/.digitalocean_dbaas_credentials` exists and `db_protocol` is `postgresql`.
- [ ] MOTD labels `db_database` as the metadata database and the credentials user as the cluster admin. The Source section shows `superset_source` and `superset_reader`. Host, port, and password come from the credentials file. It says local PostgreSQL has been stopped, and that starting it only brings the local server back.
- [ ] `SUPERSET__SQLALCHEMY_DATABASE_URI` in `/etc/superset/superset.env` uses the admin user, that host, port, and metadata database with `sslmode=require`.
- [ ] `SUPERSET__SQLALCHEMY_EXAMPLES_URI` uses `superset_reader`, the same host and port, database `superset_source`, and `sslmode=require`. It is not the admin URI.
- [ ] `https://<Droplet B public IP>` accepts `admin` and the MOTD password. That admin row lives in the managed database.
- [ ] `/var/log/superset-firstboot.log` contains `Database available` or a clear timeout, and on a fresh Droplet contains `Nothing to copy`. On success it ends with `first boot succeeded`. It does not wait forever.

## 3 · Chart table on the managed database

Droplet B · Create the chart table in managed database `superset_source` as the cluster admin. Do not use local PostgreSQL, and do not create the table in the metadata database.

- [ ] Connect to managed `superset_source` and create `public.cleaned_sales_data` with at least four rows across two product lines.
- [ ] In Superset, **New dataset** → database **Source**, schema **public**. Refresh the table list. `cleaned_sales_data` is present.

## 5 · Service helpers
Run these after the dashboard exists so a restart does not lose it.

- [ ] `/opt/status-superset.sh` shows the `superset` unit, the container, `First-boot setup: complete`, and `Health check passed`.
- [ ] `/opt/stop-superset.sh` stops Superset. The login page no longer loads. Caddy may stay running.
- [ ] `/opt/start-superset.sh` brings the login page back. Sign in and open the saved dashboard.
- [ ] `/opt/restart-superset.sh` returns the login page, and the dashboard is still present after sign-in.
