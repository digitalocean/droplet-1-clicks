# QM 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a QM 1-Click DigitalOcean Droplet image.

## Overview

[QM](https://github.com/yc-software/qm) is an open-source multiplayer agent harness. This builder creates an Ubuntu 24.04 LTS Droplet running QM's `core`, `web-ui`, and `portal` services (auth embedded in portal, admin embedded in web-ui — matching upstream's own Helm chart) behind Docker Compose, plus a bundled Postgres. Agent turns themselves run externally on [e2b](https://e2b.dev), not on this droplet.

**Why not the official `qm` CLI?** QM ships its own CLI (`@yc-software/qm`) with a `docker` deploy target, but that target's sandbox-backend policy (`cli/src/providers.ts`) refuses `e2b` on every target — it only allows `local` (mounts the host's Docker socket into `core`), `sprites`, `agent37`, or `superserve`. `core`'s own runtime validation (`src/deployment/secret-schema.ts`) has no such restriction: `e2b` is a first-class, fully supported sandbox backend there. So this builder bypasses the CLI entirely and wires the same published images the upstream Helm chart uses (`deploy/helm/values.yaml`) by hand in `files/opt/qm/compose.yml` — the same approach this repo's `qm-kubernetes` stack already takes (raw Helm values instead of the CLI).

## Directory Structure

```
qm-24-04/
├── template.json
├── README.md
├── listing.md
├── scripts/
│   └── 010-qm.sh
└── files/
    ├── etc/
    │   ├── caddy/Caddyfile.tmp
    │   ├── setup_wizard.sh
    │   └── update-motd.d/99-one-click
    ├── opt/
    │   ├── start|stop|restart|status|update-qm.sh
    │   └── qm/
    │       ├── compose.yml
    │       ├── env.template     # → /opt/qm/.env on install
    │       ├── env-lib.sh       # shared helpers for 001_onboot + setup_wizard.sh
    │       └── gen-secrets.py   # EC P-256 JWK + scrypt password hash (stdlib only)
    └── var/lib/cloud/scripts/per-instance/001_onboot
```

## Build Requirements

1. **Packer**: https://www.packer.io/downloads
2. **DigitalOcean API Token** with write access

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

```bash
packer validate qm-24-04/template.json
packer build qm-24-04/template.json
```

## What Gets Installed

- **QM** `core`, `web-ui`, `portal` — `ghcr.io/yc-software/qm/{core,web-ui,portal}`, pinned by digest to the v0.1.13 release (see `images.json` on the [release page](https://github.com/yc-software/qm/releases/tag/v0.1.13))
- **Postgres 16** — bundled, local volume, generated password
- **Caddy** — reverse proxy on 80/443 to `127.0.0.1:8081` (portal), TLS via Let's Encrypt's short-lived IP-certificate program — see "Why Caddy" below
- **UFW** — SSH (rate-limited), HTTP, HTTPS
- **fail2ban**

No Node.js, no `qm` CLI — see "Why not the official `qm` CLI?" above. Caddy is here for a reason that isn't optional; read on.

## Why Caddy (this isn't just a nicety)

The first build of this droplet shipped without Caddy — plain HTTP on the bare IP, no domain, matching a "simplest possible setup" request. Sign-in was completely broken, and the reason turned out to be a hard requirement in QM itself, not a config mistake:

1. The auth broker sets `Referrer-Policy: no-referrer` on every response (`plugins/auth/src/server.ts`'s `noStore()`). Per the Fetch spec (confirmed via MDN), a `Referrer-Policy` this restrictive makes browsers send `Origin: null` on the sign-in form's POST — a plain HTML form, not a `fetch()`/XHR call, so it can't opt into `cors` mode to avoid this.
2. `plugins/portal/src/index.ts`'s `sameOriginRequest()` check anticipates exactly this: it accepts `Origin: null` as long as `Sec-Fetch-Site: same-origin` is also present.
3. But `Sec-Fetch-Site` is a Fetch-Metadata header that browsers send **only to "potentially trustworthy" URLs — HTTPS, or literal `localhost`/loopback** (confirmed via MDN) — never to a plain HTTP request on a public IP, in any browser (this reproduced identically in Chrome incognito and Safari).
4. So on plain HTTP: `Origin` is always `null`, `Sec-Fetch-Site` is never sent, and `sameOriginRequest()` can never return true. The password form is permanently refused.
5. The CLI's own `qm admin-login` bypass (a GET-based magic link, which would sidestep the POST-only check above) is no better: `cli/src/commands/admin-login.ts` explicitly throws `"admin-login requires an HTTPS public URL (HTTP is allowed only on localhost)"`.

So every sign-in path QM ships refuses plain HTTP on a public IP, full stop. The two ways around it: (a) make the browser's origin `localhost` via an SSH tunnel (what `qm-kubernetes` effectively does with `kubectl port-forward`), or (b) give the droplet real HTTPS. This builder does (b) with Caddy + Let's Encrypt's short-lived-cert-for-a-bare-IP program (the same mechanism `omniroute-24-04`/`openhands-24-04` already use) so `https://<droplet-ip>` works directly in a browser with no domain and no tunnel. The trade-off: that IP-certificate program isn't in every browser's trust store yet, so expect a one-time warning to click through.

## First Boot Behavior

1. Generates the 8 signing secrets QM needs (`openssl rand -hex 32` each), an EC P-256 JWK for the embedded auth broker, and the Postgres password.
2. Rewrites the public-origin placeholders in `/opt/qm/.env` to `https://<droplet-ip>`.
3. Installs the Caddyfile and starts Caddy (TLS on the droplet IP — see "Why Caddy" above).
4. If `ADMIN_EMAIL`, a model key (`ANTHROPIC_API_KEY` or `OPENAI_API_KEY`), and `E2B_API_KEY` are all set as droplet environment variables, finishes configuration (generating a random admin password unless `ADMIN_PASSWORD` is also set) and starts the stack immediately — waiting 30s after `docker compose up -d` for Postgres/core to finish starting before declaring it ready. An explicit `MODEL_PROVIDER` env var picks between them; otherwise it's inferred from whichever single key was supplied, defaulting to `anthropic`.
5. Otherwise hooks `/etc/setup_wizard.sh` into root's `.bashrc` for first SSH login, and leaves the stack stopped until that wizard runs.
6. Writes `/root/qm_info.txt`.

## Auth format notes (reverse-engineered from upstream, not documented)

- `AUTH_SIGNING_JWK` must be a compact-JSON P-256 *private* JWK — same shape as `node -e "generateKeyPairSync('ec',{namedCurve:'P-256'}).privateKey.export({format:'jwk'})"` upstream's own CLI uses to mint one. `gen-secrets.py jwk` reproduces this with `openssl ecparam`/`openssl ec -text` plus stdlib `base64`, so no Node.js is needed on the droplet.
- `AUTH_PASSWORD_USERS` entries are `<email>:<scrypt-hash>` in the exact format `plugins/auth/src/password.ts` upstream expects: `scrypt$15$8$1$<salt-b64url>$<key-b64url>`, `N=2**15, r=8, p=1, dklen=32`. `gen-secrets.py hash-password` reproduces this with stdlib `hashlib.scrypt` — verified byte-for-byte against the same parameters upstream's Node implementation uses (both ultimately call into OpenSSL's scrypt).
- `PUBLIC_API_URL`/`AGENT_API_URL` (required by the newer CLI's own secret-spec whenever `HARNESS` is `pi`/`opencode`/`codex`) is **not** actually required by `core`'s runtime validation (`src/deployment/secret-schema.ts` has no entry for it at all) — that requirement is CLI-only opinion, not a hard runtime gate. This builder still sets `AGENT_API_URL`/`PUBLIC_WEB_URL` to the droplet's public IP for consistency with the Helm chart's own wiring, but does not treat it as blocking.
- Portal authenticates to the embedded auth broker as an OIDC client using `OIDC_CLIENT_ID`/`OIDC_CLIENT_SECRET` (`plugins/portal/src/index.ts`: `process.env.OIDC_CLIENT_ID ?? ""`, no fallback), while the broker itself reads `AUTH_CLIENT_ID`/`AUTH_CLIENT_SECRET` (`plugins/auth/src/config.ts`). The Helm chart's own Go template never wires these two pairs together — an operator has to set them to the same value by hand, or the broker rejects every sign-in with "This sign-in request is for an unknown application" (`plugins/auth/src/server.ts`'s `readAuthorizeRequest`, comparing the incoming `client_id` against its config with `safeEqual`). `001_onboot` generates one secret and writes it to both `AUTH_CLIENT_SECRET` and `OIDC_CLIENT_SECRET`; `env.template` hardcodes the same non-secret id (`qm-portal`) to both `AUTH_CLIENT_ID` and `OIDC_CLIENT_ID`. This same gap looks like it would also affect `qm-kubernetes` (its `values.yml` sets `AUTH_CLIENT_ID`/`AUTH_CLIENT_SECRET` but never `OIDC_CLIENT_ID`/`OIDC_CLIENT_SECRET`) — worth checking there separately.

These are internal implementation details of an early-stage upstream project (`@yc-software/qm` was at `0.1.6` at the time of writing) and could change in a future QM release — if a fresh build's login flow breaks, check `plugins/auth/src/password.ts` and the CLI's `MINT_JWK` constant upstream first.

## Version Pinning

Image digests are hardcoded in `files/opt/qm/compose.yml` (see the comment at its top). To move to a newer release: fetch that release's `images.json` from the [releases page](https://github.com/yc-software/qm/releases), copy the new `core`/`web-ui`/`portal` digests into `compose.yml` and `scripts/010-qm.sh`, rebuild the image, then on a running droplet run `/opt/update-qm.sh`.

## Droplet Size

Packer builds with `s-4vcpu-8gb`. Agent turns run externally on e2b, so this droplet only needs to carry Postgres plus the three Node services — not agent workloads.

## License

This builder configuration follows the same license as the droplet-1-clicks repository. QM licensing is governed by the upstream project (MIT).
