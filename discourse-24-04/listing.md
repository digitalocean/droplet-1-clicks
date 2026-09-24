# Discourse 1-Click Application

Deploy [Discourse](https://www.discourse.org/) — the open-source discussion platform — on Ubuntu 24.04 with Docker and the official Discourse installer.

## What is Discourse?

Discourse is a modern forum and community platform with a plugin architecture and theming system. It handles discussions, trust levels, moderation, and email-driven participation out of the box.

## Included System Components

- **Ubuntu 24.04 LTS**
- **Docker CE** — runs the Discourse container stack
- **discourse_docker** — official installer and launcher under `/var/discourse`
- **UFW** — SSH (rate-limited), HTTP, HTTPS

After first-login setup, Discourse’s installer also configures its bundled stack (PostgreSQL, Redis, nginx, Let’s Encrypt, etc.) inside Docker.

## Before You Deploy

1. **Domain name** — Discourse requires a hostname (not just an IP). Point an A record at your Droplet before or during setup.
2. **SMTP credentials** — Required for signup, password resets, and notifications (e.g. Mailgun, SendGrid, SparkPost, or another SMTP provider).

## System Requirements

| Workload | RAM | CPU | Disk |
|----------|-----|-----|------|
| Minimum | 2 GB | 2 vCPU | 25 GB |
| Recommended | 4 GB | 2+ vCPU | 50 GB+ |

This 1-Click defaults to a **2 vCPU / 4 GB** Droplet. Droplets under 2 GB RAM will have swap configured by the Discourse installer.

## Getting Started

1. Create the Droplet from this 1-Click and attach an SSH key. Wait for first-boot init (SSH is locked until `001_onboot` finishes).
2. Ensure DNS for your domain points at the Droplet IP.
3. SSH in as root: `ssh root@YOUR_DROPLET_IP`
4. Complete the interactive installer (domain, admin email, SMTP, Let’s Encrypt email). Setup takes about **10–15 minutes**.
5. Open `https://your-domain` and register the admin account using the email you provided.

## Important Paths

| Path | Purpose |
|------|---------|
| `/var/discourse` | Official Discourse Docker installer and `app.yml` |
| `/var/discourse/discourse-setup` | Re-run or adjust installer settings |
| `/var/discourse/launcher` | Start/stop/rebuild the Discourse app container |
| `/opt/digitalocean_discourse/setup_discourse.sh` | First-login wrapper (removed from bashrc after success) |

## Common Commands

```bash
cd /var/discourse
./launcher restart app
./launcher rebuild app
./launcher logs app
./discourse-setup          # re-run setup (reuses values from app.yml when present)
```

## Security Notes

- UFW allows SSH, HTTP, and HTTPS only.
- SSL is handled by Discourse’s installer (Let’s Encrypt) for your domain.
- Admin password and SMTP secrets are collected interactively at setup time and are not baked into the snapshot.

## Software License

Discourse is GPL-2.0. See https://github.com/discourse/discourse.
