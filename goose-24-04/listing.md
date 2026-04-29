# Goose 1-Click Application

Deploy [Goose](https://github.com/aaif-goose/goose), an open source, extensible AI agent for the terminal and beyond. This image installs **nginx** and **ttyd** during the build. On first **SSH** login as **root** you can set a **web console password** (nginx + HTTP Basic Auth + **Let's Encrypt** for the Droplet's **public IPv4**) or leave the password **empty** to **skip nginx** entirely and use **CLI-only** until you run **`/opt/goose/enable-web-console.sh`** later.

## What is Goose?

Goose is an AI agent framework for real work: install packages, run commands, edit files, and iterate with the LLM providers you configure. It supports many providers and extensions (including MCP) and is distributed as a CLI you can install from upstream releases.

## What this 1-Click configures

| Component | Role |
|-----------|------|
| **ttyd** | Web terminal bound to `127.0.0.1:7681` (not exposed directly). |
| **nginx** | Listens on 80/443, terminates TLS, enforces **HTTP Basic Auth**, reverse-proxies WebSockets to ttyd. |
| **Certbot (venv)** | `/opt/certbot-venv` with Certbot 5.4+ for **IP address** certificates using Let's Encrypt's **shortlived** profile (six-day lifetime; renewal is scheduled). |
| **First-login script** | `/opt/goose/first-login-setup.sh` (hooked from `/root/.bashrc` until setup completes). |
| **Enable web later** | `/opt/goose/enable-web-console.sh` — prompts for password, starts nginx, TLS, Certbot, renewal cron. |

## System requirements

| Use case | RAM | CPU |
|----------|-----|-----|
| CLI + web console, cloud models | 1 GB | 1 vCPU |
| Heavier local tooling / large repos | 2–4 GB+ | 2 vCPU+ |

## Getting started

### 1. Create the Droplet

Choose this 1-Click in the DigitalOcean Marketplace and wait for provisioning.

### 2. SSH as root (required once)

```bash
ssh root@YOUR_DROPLET_IPV4
```

The first interactive login runs the setup wizard. It will:

1. **Prompt for a web console password.** Enter the same password twice, **minimum 8 characters**, to enable nginx, HTTP Basic Auth, and the browser terminal. **Leave both prompts empty** (press Enter twice each time) if you **do not** want nginx or a public HTTPS web UI; **Goose CLI** is still installed, and you can enable the web console later with **`/opt/goose/enable-web-console.sh`**.
2. If you set a password: a **local copy** is saved at `/root/.goose_web_console_password.txt` (mode `600`). Delete this file after you store the password elsewhere.
3. Install the **Goose CLI** using the official script:

   ```bash
   curl -fsSL https://github.com/aaif-goose/goose/releases/download/stable/download_cli.sh | bash
   ```

   The wizard exports `GOOSE_BIN_DIR=/usr/local/bin` and `CONFIGURE=false` so install is non-interactive; run `goose configure` when you want provider setup.

4. **Only if you set a web password:** run **Certbot** for a **Let's Encrypt** certificate on the Droplet's **public IPv4** and configure renewal. nginx stays **stopped and disabled** when you skip the web password.

### 3. Open the web console (if enabled)

If you set a web password at first login, or you already ran **`/opt/goose/enable-web-console.sh`**, open in a browser:

```text
https://YOUR_DROPLET_IPV4/
```

- **Username:** `goose`  
- **Password:** the value you chose  

Your browser may briefly show a warning if the temporary **self-signed** certificate is still in use (for example, if Let's Encrypt issuance failed). After a successful issuance, the certificate chain is publicly trusted (short-lived IP profile).

### 3b. Enable the web console later

If you skipped the web password on first login, run as **root** over SSH:

```bash
/opt/goose/enable-web-console.sh
```

You will be prompted for a password (8+ characters). The script configures nginx, starts it, requests a Let's Encrypt IP certificate when possible, and installs the renewal cron job.

### 4. Use Goose on the CLI

```bash
goose configure    # add API keys / providers when you are ready
goose --help
```

## TLS, Let's Encrypt, and IP addresses

Let's Encrypt issues **IP address** certificates only under the **shortlived** profile (about **six days**). This image:

- Installs Certbot in `/opt/certbot-venv` (newer than the Ubuntu `apt` Certbot, so `--ip-address` and `--preferred-profile shortlived` work with **webroot** while nginx keeps serving port 80).
- Adds `/etc/cron.d/goose-certbot-renew` to run `certbot renew` twice daily with a **deploy hook** that reloads nginx (only after the web console has been enabled with a password).

If issuance fails (firewall, rate limits, or connectivity), nginx continues using `/etc/ssl/goose/selfsigned.crt` until you fix the issue and re-run Certbot manually (see `/opt/goose/README.txt`).

## Firewall and ports

UFW is configured via `014-ufw-nginx.sh`: **SSH**, **HTTP**, and **HTTPS** are allowed. ttyd is **not** exposed on a public port; only nginx is (when nginx is running). If you never use the web console, you may tighten UFW if you prefer.

## Files and paths

| Path | Purpose |
|------|---------|
| `/opt/goose/README.txt` | Operator quick reference |
| `/opt/goose/first-login-setup.sh` | First-login wizard |
| `/opt/goose/enable-web-console.sh` | Prompt for password; start nginx, TLS, Certbot, cron |
| `/root/.goose-web-console-disabled` | Present if you skipped the web password at first login |
| `/opt/goose/nginx-*.conf.tpl` | nginx templates used during boot / setup |
| `/etc/nginx/.goose-ttyd.htpasswd` | HTTP Basic credentials for the web console |
| `/root/.goose_web_console_password.txt` | Plain-text copy of the web password (remove when appropriate) |
| `/root/.goose-first-login-done` | Marker that first-login completed |
| `/opt/certbot-venv/bin/certbot` | Certbot for issuance and renewal |

## Documentation and support

- **Upstream project:** https://github.com/aaif-goose/goose  
- **DigitalOcean Community:** https://www.digitalocean.com/community  

This Marketplace image is maintained for convenience; for product bugs and features, use the upstream Goose project.
