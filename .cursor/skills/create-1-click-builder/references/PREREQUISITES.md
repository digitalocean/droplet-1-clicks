# Prerequisites

## Repositories

- **[droplet-1-clicks](https://github.com/digitalocean/droplet-1-clicks)** checkout on disk (`DROPLET_REPO`)
- Work **only** inside the assigned `<app>-24-04/` directory for that 1-click

## Tools

- **[Packer](https://developer.hashicorp.com/packer)** on `PATH`
- DigitalOcean Packer plugin — run `packer init` in the app directory if `plugins.pkr.hcl` exists

## Credentials

- **`DIGITALOCEAN_API_TOKEN`** — required for `packer build` (DigitalOcean builder snapshots)
- Never commit tokens or generated secrets into the repo

## Build commands

From the app directory:

```bash
cd "$DROPLET_REPO/$REPO_DIR"
packer init .    # if plugins.pkr.hcl present
packer build template.json
```

Or from repo root with explicit path:

```bash
cd "$DROPLET_REPO"
packer build -force "$REPO_DIR/template.json"
```

## Related skills

| Skill | Use when |
|-------|----------|
| **create-1-click-builder** (this) | Authoring templates and scripts |
| **onboard-1-click-autoupdate** | After builder is stable — autoupdate service |
| **update-1-click-image** | One-off snapshot refresh for an **existing** Vendor Portal app |

Initial Marketplace **listing creation** is via [Vendor Portal UI](https://cloud.digitalocean.com/vendorportal), not a skill in this repo.
