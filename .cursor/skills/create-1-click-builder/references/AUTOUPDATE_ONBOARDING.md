# Autoupdate onboarding (after builder)

For **DigitalOcean-owned** 1-clicks that should receive scheduled rebuilds and QA, onboard the app into the **autoupdate** service after the Packer builder is stable.

## When

- New 1-click builder merged or validated with a successful `packer build`
- Existing builder added to the autoupdate pipeline for the first time

## What to do

Use the **onboard-1-click-autoupdate** skill (`/onboard-1-click-autoupdate` in Cursor/OpenCode/Claude). It covers:

1. `autoupdateapps` database row
2. `scripts/autoupdate/latestversion/<app_name>.sh` (manual-version apps only)
3. `scripts/autoupdate/qa/<app_name>/testN.sh` and `./scripts/test-qa.sh` validation

## Naming note

Autoupdate **`app_name`** may differ from the droplet-1-clicks folder (e.g. `plausible-24-04` → `plausible-analytics`). See **onboard-1-click-autoupdate** skill `references/APP_NAME_MAP.md`.

## Reference

- Autoupdate service README: `cthulhu/docode/src/do/teams/marketplace/autoupdate/README.md` in the internal monorepo

This skill does **not** perform autoupdate DB writes or script scaffolding unless the user explicitly requests autoupdate work in the same session — prefer invoking the onboard skill.
