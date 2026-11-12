# Nod 1-Click Builder

Packer template that builds an Ubuntu 24.04 Marketplace image for [Nod](https://github.com/n8n-io/nod) using the official Docker self-host stack (`deployment/self-host`).

## Layout

```
nod-24-04/
├── template.json
├── listing.md
├── readme.md
├── scripts/010-nod.sh
└── files/
    ├── etc/caddy/Caddyfile.tmp
    ├── etc/systemd/system/nod.service
    ├── etc/update-motd.d/99-one-click
    ├── opt/{start,stop,restart,status,update,setup-nod-domain,nod-compose}.sh
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## How it works

1. **Packer** installs Docker Engine 25+, Caddy, clones `nod-v${application_version}`, and pre-builds Compose images.
2. **First boot** runs Nod's `setup.sh` to create unique `NOD_AUTH_TOKEN`, `NOD_VAULT_KEY`, and `NOD_POSTGRES_PASSWORD`, sets `NOD_PUBLIC_URL` to `https://<droplet-ip>`, configures Caddy shortlived TLS, optionally applies DigitalOcean Serverless Inference from `MODEL_ACCESS_KEY`, and starts the stack.
3. Users open the HTTPS URL and paste the access token from the MOTD.

Host Caddy is used instead of Compose `--profile https` so Marketplace IP certs match other agent 1-clicks.

### Serverless Inference

If `MODEL_ACCESS_KEY` is set (droplet env or `/opt/nod.env`), `/opt/apply-inference-from-env.sh` configures Nod as:

- `LLM_PROVIDER=compatible`
- `OPENAI_COMPATIBLE_BASE_URL=https://inference.do-ai.run/v1`
- `OPENAI_COMPATIBLE_API_KEY=<key>`
- `LLM_MODEL=<INFERENCE_MODEL or router:<name>>`

Otherwise first SSH runs `/etc/setup_wizard.sh`. Shared model listing helpers come from `common/files/var/lib/digitalocean/inference-models.sh`.

## Build

Requires `DIGITALOCEAN_API_TOKEN` and Packer.

```bash
cd /path/to/droplet-1-clicks
packer build nod-24-04/template.json
```

Pin the Nod release via `application_version` in `template.json` (maps to git tag `nod-v<version>`).

## Runtime paths

| Item | Path |
|------|------|
| Source | `/opt/nod` |
| Compose / `.env` | `/opt/nod/deployment/self-host` |
| Helpers | `/opt/*.sh` |
| Service | `nod.service` |

## Notes

- Recommended droplet size: **8 GB / 2 vCPU** minimum.
- Do not commit `.env` or tokens from a built droplet.
- After a successful Marketplace listing exists, use Vendor Portal for submission; autoupdate onboarding is a separate skill.
