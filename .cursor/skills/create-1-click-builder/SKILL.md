---
name: create-1-click-builder
description: >
  Create or update Droplet Marketplace Packer builders in droplet-1-clicks:
  Ubuntu 24-04, provisioners, systemd, Docker/Caddy patterns, listing.md.
  Use for new 1-clicks, packer templates, onboot/MOTD, or troubleshooting builders.
  Does NOT create Marketplace listings or PATCH Vendor Portal (use update-1-click-image
  only to refresh an existing listing). After a new builder, use onboard-1-click-autoupdate
  for the autoupdate service.
disable-model-invocation: true
metadata:
  team: marketplace-engineering
  domain: droplet-1-clicks
  status: stable
---

# Create 1-Click Builder

User request: $ARGUMENTS

## Scope

Author **new or updated** Packer builders in a [droplet-1-clicks](https://github.com/digitalocean/droplet-1-clicks) checkout. Follow [references/DROPLET_1_CLICK_AGENT.md](references/DROPLET_1_CLICK_AGENT.md) (verbatim upstream agent guide).

Work **only** inside the target `<app>-24-04/` directory.

This skill does **not**:

- Create a **new** Marketplace listing (use [Vendor Portal UI](https://cloud.digitalocean.com/vendorportal))
- PATCH Vendor Portal or submit `imageId` (use skill **update-1-click-image** for **existing** apps only)
- Onboard autoupdate (use skill **onboard-1-click-autoupdate** unless the user asks for autoupdate in the same session)

## When to use

- Build a new droplet 1-click from scratch or from `_template/`
- Update provisioners, systemd, onboot, MOTD, Caddy, or `template.json` for an existing app dir
- Troubleshoot a failing Packer build for one app

## When NOT to use

- Rebuild and PATCH an existing Vendor Portal listing without template changes → **update-1-click-image**
- Batch rebuild many 1-clicks → [1-click-updater](https://github.com/digitalocean/1-click-updater)
- Autoupdate DB / QA scripts → **onboard-1-click-autoupdate**

## Required inputs

| Input | Description |
|-------|-------------|
| `DROPLET_REPO` | Path to droplet-1-clicks checkout |
| `REPO_DIR` | App folder (e.g. `myapp-24-04`) — create or existing |
| Software / product name | What to install and document |

Optional: reference 1-clicks for patterns (`campfire-24-04`, `coolify-24-04` for Docker).

## Workflow

0. **Branch** — All edits in `$DROPLET_REPO` happen on a feature branch, not `master`. Before creating the branch, update `master`:

   ```bash
   cd "$DROPLET_REPO"
   git fetch origin
   git checkout master
   git pull origin master
   git checkout -b add-<REPO_DIR>
   ```

   Use a descriptive branch name when the user provides one (e.g. `add-opencode-24-04`). Do not commit directly to `master`.

1. **Research** — official install docs; prefer Docker when appropriate (Campfire/Coolify patterns).
2. **Scaffold** — copy [`_template/`](https://github.com/digitalocean/droplet-1-clicks/tree/master/_template) to `<name>-24-04/` if new; see [references/DIRECTORY_STRUCTURE.md](references/DIRECTORY_STRUCTURE.md).
3. **Configure** — set `application_version` and related variables in `template.json`; use `ubuntu-24-04-x64` for new builders.
4. **Implement** — add `files/`, `scripts/`, systemd units, onboot, MOTD; copy via Packer `file` provisioners (**never** generate helper scripts inside another shell script).
5. **HTTP apps** — Caddy + short-lived ACME IP cert per agent guide (see DROPLET_1_CLICK_AGENT.md §10).
6. **Docs** — `listing.md` and `readme.md` in the app directory.
7. **Build loop** — from `$DROPLET_REPO/$REPO_DIR`:

   ```bash
   packer init .   # if plugins.pkr.hcl exists
   packer build template.json
   ```

   On failure: analyze log, fix, retry up to **5** attempts.

## After a successful build

| Situation | Next step |
|-----------|-----------|
| **New listing** | User completes submission in [Vendor Portal](https://cloud.digitalocean.com/vendorportal). Do **not** use update-1-click-image (needs existing `appId`). |
| **DO-owned + automated updates** | Invoke **onboard-1-click-autoupdate** — see [references/AUTOUPDATE_ONBOARDING.md](references/AUTOUPDATE_ONBOARDING.md). |
| **Existing app, snapshot only** | Optionally **update-1-click-image** if user only needs a one-off PATCH. |

## Additional resources

- [references/DROPLET_1_CLICK_AGENT.md](references/DROPLET_1_CLICK_AGENT.md) — full authoring rules
- [references/DIRECTORY_STRUCTURE.md](references/DIRECTORY_STRUCTURE.md)
- [references/PREREQUISITES.md](references/PREREQUISITES.md)
- [references/AUTOUPDATE_ONBOARDING.md](references/AUTOUPDATE_ONBOARDING.md)
- [README.md](README.md) — install and invoke
