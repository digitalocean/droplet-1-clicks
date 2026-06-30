# create-1-click-builder

Author **new or updated** [droplet-1-clicks](https://github.com/digitalocean/droplet-1-clicks) Packer builders for the DigitalOcean Marketplace: Ubuntu 24.04, provisioners, systemd, Docker/Caddy patterns, `listing.md`, and `readme.md`.

This skill does **not** create Vendor Portal listings, PATCH snapshots, or onboard autoupdate (use sibling skills below).

## When to use

- Create a new `<app>-24-04/` builder from `_template/`
- Modify templates, scripts, onboot, or MOTD for one 1-click
- Fix a failing `packer build` for a single app directory

## Post-builder checklist

1. **Vendor Portal** — for a **new** listing, submit via [Vendor Portal UI](https://cloud.digitalocean.com/vendorportal) (human step).
2. **Autoupdate** — for DO-owned apps with scheduled rebuilds, run **[onboard-1-click-autoupdate](../onboard-1-click-autoupdate/README.md)**.
3. **Optional refresh** — one-off snapshot PATCH for an **existing** app: **[update-1-click-image](../update-1-click-image/README.md)**.

## Prerequisites

See [references/PREREQUISITES.md](references/PREREQUISITES.md) — Packer, `DIGITALOCEAN_API_TOKEN`, droplet-1-clicks checkout.

## Install

From the marketplace-skills repo root:

```bash
./scripts/install-skill.sh create-1-click-builder --target agents
./scripts/install-skill.sh create-1-click-builder --target cursor
./scripts/install-skill.sh create-1-click-builder --target opencode
./scripts/install-skill.sh create-1-click-builder --target claude
```

Add `--global` for user-level install (`~/.cursor/skills/`, etc.).

## Invoke

| Client | Command |
|--------|---------|
| **Cursor** | `/create-1-click-builder` or `@create-1-click-builder` |
| **OpenCode** | `/create-1-click-builder` in the TUI |
| **Claude Code** | `/create-1-click-builder` |

`disable-model-invocation: true` — invoke explicitly.

Example:

```
/create-1-click-builder Build opencode-24-04 in /path/to/droplet-1-clicks.
Follow Docker pattern from campfire-24-04. Run packer build when ready.
```

## Test

```bash
./skills/create-1-click-builder/tests/run.sh
./scripts/validate-all.sh skills/create-1-click-builder
```

## Related skills

| Skill | Role |
|-------|------|
| [onboard-1-click-autoupdate](../onboard-1-click-autoupdate/README.md) | Autoupdate DB, latestversion, QA scripts |
| [update-1-click-image](../update-1-click-image/README.md) | Existing listing: packer + Vendor Portal PATCH |
| [1-click-updater](https://github.com/digitalocean/1-click-updater) | Batch plan/build |

## References

- Upstream agent guide: [references/DROPLET_1_CLICK_AGENT.md](references/DROPLET_1_CLICK_AGENT.md)
- [droplet-1-clicks](https://github.com/digitalocean/droplet-1-clicks)
