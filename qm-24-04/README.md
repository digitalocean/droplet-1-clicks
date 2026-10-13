# QM 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a QM 1-Click DigitalOcean Droplet image.

## Overview

[QM](https://github.com/yc-software/qm) is an open-source multiplayer agent harness. This builder creates an Ubuntu 24.04 LTS Droplet running QM's `core`, `web-ui`, and `portal` services (auth embedded in portal, admin embedded in web-ui — matching upstream's own Helm chart) behind Docker Compose, plus a bundled Postgres. The setup wizard asks for a model provider (DigitalOcean Serverless Inference, Anthropic, or OpenAI — see "DigitalOcean Serverless Inference as model provider" below) and a sandbox backend for where agent turns actually run ([DigitalOcean Managed Agents](https://github.com/nkurraDO/qm) or e2b — see "DigitalOcean Managed Agents sandbox backend" below), neither of which run on this droplet itself.

**Why not the official `qm` CLI?** QM ships its own CLI (`@yc-software/qm`) with a `docker` deploy target, but that target's sandbox-backend policy (`cli/src/providers.ts`) refuses `e2b` on every target — it only allows `local` (mounts the host's Docker socket into `core`), `sprites`, `agent37`, or `superserve`. `core`'s own runtime validation (`src/deployment/secret-schema.ts`) has no such restriction: `e2b` is a first-class, fully supported sandbox backend there. So this builder bypasses the CLI entirely and wires the same published images the upstream Helm chart uses (`deploy/helm/values.yaml`) by hand in `files/srv/qm/compose.yml` — the same approach this repo's `qm-kubernetes` stack already takes (raw Helm values instead of the CLI).

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
    ├── srv/
    │   └── qm/
    │       ├── start|stop|restart|status|update-qm.sh
    │       ├── compose.yml
    │       ├── env.template     # → /srv/qm/.env on install
    │       ├── env-lib.sh       # shared helpers for 001_onboot + setup_wizard.sh
    │       └── gen-secrets.py   # EC P-256 JWK + scrypt password hash + signed admin requests (stdlib only)
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

- **QM** `web-ui`, `portal` — `ghcr.io/yc-software/qm/{web-ui,portal}`, pinned by digest to the v0.1.13 release (see `images.json` on the [release page](https://github.com/yc-software/qm/releases/tag/v0.1.13))
- **QM** `core` — built from source at Packer build time from the [DigitalOcean Managed Agents fork](https://github.com/nkurraDO/qm), branch `managed-agents-workspace-scratch` (yc-software/qm PR #2221), pinned commit `cf711d04` (see "DigitalOcean Managed Agents sandbox backend" below)
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
2. Rewrites the public-origin placeholders in `/srv/qm/.env` to `https://<droplet-ip>`.
3. Installs the Caddyfile and starts Caddy (TLS on the droplet IP — see "Why Caddy" above).
4. If `ADMIN_EMAIL`, a model key (`DO_SERVERLESS_INFERENCE_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY`), and a sandbox key (`DO_AGENTS_API_TOKEN` — DigitalOcean Managed Agents' env var — or `E2B_API_KEY`) are all set as droplet environment variables, finishes configuration (generating a random admin password unless `ADMIN_PASSWORD` is also set) and starts the stack immediately — waiting 30s after `docker compose up -d` for Postgres/core to finish starting before declaring it ready, then (if DigitalOcean Serverless Inference was chosen) registering it as the default model — see "DigitalOcean Serverless Inference as model provider" below. Explicit `MODEL_PROVIDER`/`SANDBOX_BACKEND` env vars pick between the options; otherwise each is inferred from whichever single key was supplied (defaulting to `anthropic` / `e2b` — the interactive wizard instead defaults to DigitalOcean Serverless Inference / DigitalOcean Managed Agents; see below).
5. Otherwise hooks `/etc/setup_wizard.sh` into root's `.bashrc` for first SSH login, and leaves the stack stopped until that wizard runs.
6. Writes `/root/qm_info.txt`.

## Auth format notes (reverse-engineered from upstream, not documented)

- `AUTH_SIGNING_JWK` must be a compact-JSON P-256 *private* JWK — same shape as `node -e "generateKeyPairSync('ec',{namedCurve:'P-256'}).privateKey.export({format:'jwk'})"` upstream's own CLI uses to mint one. `gen-secrets.py jwk` reproduces this with `openssl ecparam`/`openssl ec -text` plus stdlib `base64`, so no Node.js is needed on the droplet.
- `AUTH_PASSWORD_USERS` entries are `<email>:<scrypt-hash>` in the exact format `plugins/auth/src/password.ts` upstream expects: `scrypt$15$8$1$<salt-b64url>$<key-b64url>`, `N=2**15, r=8, p=1, dklen=32`. `gen-secrets.py hash-password` reproduces this with stdlib `hashlib.scrypt` — verified byte-for-byte against the same parameters upstream's Node implementation uses (both ultimately call into OpenSSL's scrypt).
- `PUBLIC_API_URL`/`AGENT_API_URL` (required by the newer CLI's own secret-spec whenever `HARNESS` is `pi`/`opencode`/`codex`) is **not** actually required by `core`'s runtime validation (`src/deployment/secret-schema.ts` has no entry for it at all) — that requirement is CLI-only opinion, not a hard runtime gate. This builder still sets `AGENT_API_URL`/`PUBLIC_WEB_URL` to the droplet's public IP for consistency with the Helm chart's own wiring, but does not treat it as blocking.
- Portal authenticates to the embedded auth broker as an OIDC client using `OIDC_CLIENT_ID`/`OIDC_CLIENT_SECRET` (`plugins/portal/src/index.ts`: `process.env.OIDC_CLIENT_ID ?? ""`, no fallback), while the broker itself reads `AUTH_CLIENT_ID`/`AUTH_CLIENT_SECRET` (`plugins/auth/src/config.ts`). The Helm chart's own Go template never wires these two pairs together — an operator has to set them to the same value by hand, or the broker rejects every sign-in with "This sign-in request is for an unknown application" (`plugins/auth/src/server.ts`'s `readAuthorizeRequest`, comparing the incoming `client_id` against its config with `safeEqual`). `001_onboot` generates one secret and writes it to both `AUTH_CLIENT_SECRET` and `OIDC_CLIENT_SECRET`; `env.template` hardcodes the same non-secret id (`qm-portal`) to both `AUTH_CLIENT_ID` and `OIDC_CLIENT_ID`. This same gap looks like it would also affect `qm-kubernetes` (its `values.yml` sets `AUTH_CLIENT_ID`/`AUTH_CLIENT_SECRET` but never `OIDC_CLIENT_ID`/`OIDC_CLIENT_SECRET`) — worth checking there separately.

These are internal implementation details of an early-stage upstream project (`@yc-software/qm` was at `0.1.6` at the time of writing) and could change in a future QM release — if a fresh build's login flow breaks, check `plugins/auth/src/password.ts` and the CLI's `MINT_JWK` constant upstream first.

## Version Pinning

`web-ui`/`portal` digests default inside `files/srv/qm/compose.yml` (`${QM_WEBUI_IMAGE:-<pinned digest>}` etc. — see the comment at its top); `scripts/010-qm.sh` just runs `docker compose pull web-ui portal postgres`, no digests duplicated there. To move them to a newer upstream release: fetch that release's `images.json` from the [releases page](https://github.com/yc-software/qm/releases) and replace their default digests in `compose.yml`, rebuild the image, then on a running droplet run `/srv/qm/update-qm.sh`.

`core` is pinned differently — see below.

## DigitalOcean Managed Agents sandbox backend

A teammate (DigitalOcean's Managed Agents team) added a custom sandbox backend to a fork of QM: [`nkurraDO/qm`](https://github.com/nkurraDO/qm), branch `managed-agents-workspace-scratch` — this is [yc-software/qm PR #2221](https://github.com/yc-software/qm/pull/2221), pinned commit `cf711d0491a2de76bf17bb8bc0c8a4e8753f5540` ("Make the Managed Agents fake enforce workspace confinement"). **Managed Agents** (DigitalOcean's product for running coding agents in managed Firecracker microVMs — formerly/internally called MARS, Managed Agent Runtime Stack) lets a QM deployment use DO's own infrastructure instead of e2b for agent sandboxes. This fork has now adopted the formalized `do-managed-agents`/`DO_AGENTS_*` naming (an earlier pinned commit, `787ff972`, used the older `mars`/`MARS_*` names — this droplet's own scripts/docs have been updated to match). Read `adrs/managed-agents-sandbox-backend.md` and `docs/managed-agents.md` in that fork for the full design; this is the short version of what matters for this droplet.

**Pin bumped (15e71bf0 → cf711d04) specifically for PR #2221's fix** — see "A real bug, found live and now fixed upstream" below for the full story: this isn't just a routine bump, it fixes two real bugs confirmed against this droplet.

**Why build from source instead of pulling an image**: the fork has no published release or image yet (checked the GitHub API — zero releases as of this writing). So `scripts/010-qm.sh` clones it at the pinned commit above and runs `docker build -f deploy/core/Dockerfile` itself, tagging the result `qm-core-managed-agents:cf711d04`. This is a one-time cost at Packer build time, not something every droplet boot repeats.

**The `npm audit` gate issue from earlier pins is resolved — confirmed with a real build, not just reading the Dockerfile.** `deploy/core/Dockerfile`'s audit gate (now `npm run audit:prod`, a package.json script wrapping the same `npm audit --omit=dev --audit-level=moderate`) failed at both earlier pins (`787ff972`, then `15e71bf0`) on open `fastify`/`hono` advisories, and `scripts/010-qm.sh` used to `sed`-patch that line out to get a build at all. At this commit: `fastify` is `5.12.5` (patched exactly at 5.12.5 per [GHSA-4mh8-r7rc-xpvc](https://github.com/advisories/GHSA-4mh8-r7rc-xpvc)) and `hono` is `4.13.9` (patched at 4.13.7 per [GHSA-hxh3-vqpv-xpqv](https://github.com/advisories/GHSA-hxh3-vqpv-xpqv)) — both advisories resolved upstream. Ran `docker build --no-cache` against this exact commit to confirm rather than trust the lockfile alone: `npm audit --omit=dev --audit-level=moderate` → `found 0 vulnerabilities`. **The sed-patch is gone from `scripts/010-qm.sh`** — no longer needed at this pin. If a future bump reintroduces a real advisory, the old patch is still in this file's git history.

**Why only `core` changes**: the fork's Managed Agents commits touch only `src/sandbox/*`, `src/config.ts`, `src/wiring.ts`, `src/deployment/secret-schema.ts`, the vendored proto/tunnel, docs, and tests — nothing under `plugins/web-ui` or `plugins/portal`. So `web-ui`/`portal` stay on the pinned upstream v0.1.13 images, unaffected.

**Why one image serves both sandbox backends**: the fork is a pure superset of upstream — it adds `SANDBOX_BACKEND=do-managed-agents` alongside the existing `e2b`/`local`/etc. backends without removing or changing any of them. So the same `qm-core-managed-agents:cf711d04` image is `core`'s image regardless of which backend the setup wizard's user picks; only the runtime env vars (`SANDBOX_BACKEND`, `DO_AGENTS_API_TOKEN` vs. `E2B_API_KEY`) differ.

**Exact env vars** (confirmed from `src/deployment/secret-schema.ts` in the fork at this commit, the same runtime gate e2b uses): `SANDBOX_BACKEND=do-managed-agents` requires `DO_AGENTS_API_TOKEN` (a standard DigitalOcean personal access token — `cloud.digitalocean.com/account/api/tokens` — nothing special to provision; it also carries the DO team identity). Everything else the fork supports (`DO_AGENTS_TEMPLATE`, `DO_AGENTS_NAME_PREFIX`, `DO_AGENTS_API_BASE_URL`, `DO_AGENTS_SIZE_SLUG`, `DO_AGENTS_IDLE_TIMEOUT_SEC`, `DO_AGENTS_EGRESS_PROXY_URL`, `DO_AGENTS_SNAPSHOT_S3_BUCKET`, `DO_AGENTS_SNAPSHOT_INTERVAL_SEC`, etc.) is optional and left unset — this droplet doesn't collect them, matching e2b's own treatment (we don't collect `E2B_EGRESS_PROXY_URL` either). `src/config.ts` at this commit logs (non-fatal) warnings when `DO_AGENTS_API_TOKEN` is set without `DO_AGENTS_EGRESS_PROXY_URL` (no egress enforcement) or without `DO_AGENTS_SNAPSHOT_S3_BUCKET` (a destroyed/reclaimed session loses its home) — worth knowing if a real deployment ever needs either.

**Core-reachability requirement, and why we didn't have to change anything for it**: this backend's microVMs call back into core's self-API (capability tokens, connector credentials, crons), so core's public URL must be reachable from outside — same requirement e2b has. Checked `plugins/portal/src/index.ts`: there's already a generic `/v1/*` → `core` proxy gated on a valid agent capability token, and `AGENT_API_URL` is already set to `https://<droplet-ip>` (via Caddy) for e2b's sake. So DigitalOcean Managed Agents should work through the exact same path with no new Caddy vhost. Not yet proven end-to-end with a live turn on this backend, though — worth a real smoke test.

**A new requirement introduced by this commit, not present in the older `mars`-named one**: this version's data plane is a gRPC tunnel over a WebSocket port-forward (`/v2/agents/sessions/{id}/port-forward/8443`), not plain REST exec. DigitalOcean's own docs for this backend warn that a droplet resolving `api.digitalocean.com` through the VPC-local DNS resolver gets an internal address that serves REST fine but refuses the WebSocket upgrade with a bare `403` — lifecycle calls look healthy right up until the first command. **Not yet checked whether this droplet's default DNS resolver is affected** — verify on the next real deployment, and if so, point the droplet at a public resolver (see that backend's own docs for the exact `/etc/netplan`/`systemd-resolved` fix).

**To bump the pinned commit later**: update `QM_FORK_SHA`/`QM_CORE_MANAGED_AGENTS_TAG` in `scripts/010-qm.sh` and the default in `compose.yml`, rebuild. If the fork ever publishes a real image, `QM_CORE_IMAGE` in `.env` can point at it directly instead of building from source — no other changes needed.

**Auto-detecting an injected Managed Agents token**: DigitalOcean's own internal automation can inject a Managed Agents PAT (`dop_v1_...`, scoped to `agent_harness_session` create/read/operate/manage/share) into the same credentials file the GenAI model-provider automation uses (`/root/.digitalocean_genai_credentials` — see "Auto-detecting DigitalOcean's own GenAI automation" below), as an independent `MANAGED_AGENTS_TOKEN` field — a droplet can get the model key, this token, both, or neither. `env-lib.sh`'s `detect_managed_agents_token()` parses it separately from `detect_do_genai_credentials()` for exactly that reason. When present, both `setup_wizard.sh` and `001_onboot` skip the sandbox-backend question entirely and always select DigitalOcean Managed Agents with that token, same "always wins" precedence as the model-provider auto-detection.

**A real bug, found live, worked around, then fixed upstream — the whole arc**: publishing a web app from a Managed Agents sandbox failed with `"path outside workspace: allowed root is /workspace"`, found via a client's live publish attempt. Traced to a genuine mismatch between two components: QM's own generic export code (`src/sandbox/exec-file-ops.ts` upstream, shared by every sandbox backend) staged published bundles at a hardcoded `mktemp /tmp/agent-computer-export.XXXXXX`, but the Managed Agents sandbox-agent's file-transfer guard only allows paths under `/workspace`. At the time, this droplet carried a workaround using QM's own "deployment layer" extensibility mechanism (a `tools/<id>/tool.json` directory `core` installs into every new sandbox at provision time) to ship a `mktemp` shim redirecting just that one export path into `/workspace/tmp`.

**That workaround is now removed** — [yc-software/qm PR #2221](https://github.com/yc-software/qm/pull/2221) (the pin this droplet now builds from) fixes this properly upstream, and turned out to fix a second, bigger bug in the same pass: *any* command needing a credential was *also* failing on Managed Agents, for the identical reason (credential staging used the same shared `/tmp` scratch path). The real fix: backends now declare a `scratchDir` — defaults to `/tmp` everywhere else, but Managed Agents declares `/workspace/.qm-scratch`, a path both exec *and* file-transfer can see — used for both credential staging and export. Confirmed by reading the new commit's source directly (`src/sandbox/managed-agents-sandbox.ts`'s `SCRATCH_DIR = "/workspace/.qm-scratch"`, wired into `exec-file-ops.ts`'s both affected call sites) — our shim's old `/tmp/agent-computer-export.*` pattern would simply never match this new path, so it was dead weight once this pin landed, and has been deleted (`files/srv/qm/deployment-layer/`, the `DEPLOYMENT_LAYER` env var and bind mount in `compose.yml`).

Not yet verified against a live Managed Agents sandbox that publishing and credentialed commands both actually work now — that's the next real test, same as every pin bump in this project.

## DigitalOcean Serverless Inference as model provider

DO's Serverless Inference (`https://inference.do-ai.run`) speaks the OpenAI Chat Completions wire protocol but isn't `api.openai.com` and its keys use a different prefix (`doo_v1_...` vs OpenAI's `sk-...`), so it can't just be dropped into `MODEL_PROVIDER=openai`. Worse, QM's `openai` provider slot defaults to a hardcoded model id (`gpt-5.6-sol`) that DO doesn't serve, and that id can't be overridden to an arbitrary string for a built-in provider — only to ids QM already knows about.

The real mechanism is QM's **custom model providers** feature (`src/model/custom-providers.ts` upstream, mainline — not a fork): *"An org admin can register additional model providers that speak a wire protocol we already run — OpenAI Chat Completions, OpenAI Responses, or Anthropic Messages — by giving a base URL, an API key, and the model ids to expose."* It's normally a post-deploy, Admin-console action (`PUT /v1/admin/custom-providers/:id`, durable in Postgres, the API key encrypted at rest with a key derived from `CONNECTOR_SECRET_KEY`). This droplet automates that registration at first boot instead, so choosing DigitalOcean Serverless Inference in the wizard needs only the one key — no Anthropic/OpenAI key, no manual Admin-console step.

**How the automation works**: QM's own `src/deployment/postdeploy-smoke.ts` (the live-deployment canary `qm check --live` runs) calls these same admin-gated endpoints non-interactively, using a signed-request scheme built entirely from secrets this droplet already generates — `CORE_SIGNING_SECRET` and `PORTAL_IDENTITY_SECRET`. Traced the exact signing code and reproduced it in `gen-secrets.py` (stdlib only, no Node/jose needed):

- Request signing (`src/auth/source-auth-sign.ts`): `x-signature: v0=` + `HMAC-SHA256(CORE_SIGNING_SECRET, "v0:{timestamp}:{METHOD}\n{path}\n{body}")`, plus `x-timestamp`.
- Identity (`src/auth/signed-token.ts`): a JWS compact token (`HS256`, RFC 7515 — unambiguous, no library-specific behavior to diverge from), signed with `PORTAL_IDENTITY_SECRET`, payload `{"p": "<admin-email>", "exp": <now+60s>}`, header `x-portal-identity`.
- Plus `x-admin-actor: <admin-email>@qm` naming the acting principal.

Checked this isn't a public-facing hole: `plugins/portal/src/proxy.ts` explicitly strips `x-admin-actor`/`x-signature`/`x-timestamp`/`x-portal-identity` on any externally-facing proxy path — these are only trusted for internal-to-internal calls, which is exactly what `env-lib.sh`'s `register_do_inference_provider()` is (it runs on the same box, reaching `core` directly inside its own container via `docker exec` — `core` has no published host port, but its image already has `curl`).

**Default model**: [`deepseek-v4.1-flash`](https://cloud.digitalocean.com/model-studio/explore-models/model-catalog/deepseek-v4.1-flash) (context window and max output tokens per [DigitalOcean's model docs](https://docs.digitalocean.com/products/gradient-ai-platform/details/models/), cross-checked against two independent fetches of that page). Making it the actual *default* model (not just an available one) needed one more piece: `baseModelDefault` in core traces back to the `PI_MODEL` env var (`config.ts`: `env.PI_MODEL ? { modelId: env.PI_MODEL } : ...`) — a second, completely separate mechanism from the custom-provider registration. Both are set: the provider registration makes `deepseek-v4.1-flash` *resolvable*, `PI_MODEL=deepseek-v4.1-flash` makes it the *default*. `env-lib.sh` keeps the model id/name/context-window/max-tokens as one set of constants (`DO_INFERENCE_MODEL_ID` etc.) so both line up and there's one place to change them.

When this path is chosen, `MODEL_PROVIDER` is left **blank**, not set to some sentinel — core runs "modelless" at the built-in-provider level, which is an explicitly supported upstream configuration (`deployment.md`: *"An operator may still prefer to hold the key centrally and rotate it from the Admin page... drop modelProvider... Never leave a deployment modelless without saying so."*). `DO_SERVERLESS_INFERENCE_API_KEY` in `.env` is this droplet's own bookkeeping only (idempotency checks, visibility) — core never reads it directly, since the real key only ever travels inside the one signed registration request, encrypted at rest by core itself afterward.

### Verified live, and a real upstream gap found + worked around

Tested this against an actual running droplet (not just the local stand-in server). Two findings:

1. **The signed registration itself works perfectly as designed.** `docker logs qm-core` showed `PUT /v1/admin/custom-providers/digitalocean 200`, `GET /v1/admin/custom-providers` confirmed `"hasKey":true`, and replaying QM's own live-session canary (`postdeploy-smoke.ts`'s exact `POST /v1/turns` flow) end to end got back the real model's reply verbatim. The model genuinely works.

2. **But the admin still landed on a stuck onboarding page ("Configure API key for DigitalOcean...") with no way to dismiss it.** Traced this to a real upstream gap, not anything wrong with our registration: `plugins/portal/src/index.ts` hard-redirects every browser request for the main web-ui to `/admin/onboarding` whenever `modelProviderConfigured` is false — and that flag (`src/api/routes/surface.ts`) is computed as `providerStatus.anthropic || providerStatus.openai || providerStatus.openrouter || providerStatus.modelIds?.size || ...`. `providerStatus` comes from `model-credential-store.ts`'s `availability()`, which **only ever reflects the 3 built-in provider credential slots** — it has no concept of custom providers at all. `modelIds` turned out to be an unrelated "model gateway" mechanism (`gatewayTransport.models`), not custom providers either. Confirmed live: `GET /v1/surface-config` kept returning `"modelProviderConfigured":false` even with the custom provider fully registered and already answering real chat turns correctly — this isn't a caching delay, it's structural. The onboarding page's own "Configure API key" save button also calls the wrong endpoint for a custom provider (`PUT /v1/admin/model-providers/digitalocean` — the built-in-only route, which doesn't recognize a `digitalocean` id — 404), so there's no way to clear the gate through the UI either.

**The fix** (confirmed live — `modelProviderConfigured` flips to `true`, chat still works correctly afterward): when the DO-inference path is chosen, also write the *same* key to `OPENAI_API_KEY` as a bystander credential. `model-credential-store.ts`'s `fallback.openai` is wired directly to `config.openaiApiKey` (the plain env var) — just having it present satisfies `modelProviderConfigured`, regardless of `MODEL_PROVIDER` being blank. It doesn't change which model actually answers (`PI_MODEL` and the custom-provider registration still govern that exclusively) — it's purely there to satisfy a status check that has no custom-provider awareness. The one side effect: built-in OpenAI-branded models (`gpt-5.6-sol` etc.) become *selectable* in the picker and would fail if a user manually switched to one, since this isn't a real OpenAI key — see the third finding below for how this got closed off too. Worth revisiting if upstream ever makes `modelProviderConfigured` custom-provider-aware (check `providerKeysPresent`/`model-credential-store.ts`/`surface.ts` again before removing this).

3. **A third, separate gate: the web UI's per-turn model picker refused the already-working model** ("that model is not enabled for the web UI"), found after the onboarding-gate fix above was confirmed working and a real chat message was sent. Traced to yet another independent mechanism from the two above: `src/core/turn-options.ts`'s `validateWebTurnModelOptions` checks the requested model id against an **org-scoped durable allowlist** — `src/api/app-turn.ts` reads it via `deps.config.getWebuiModelsDurable(org)`; when unset (the default), it falls back to `src/model/pi-models.ts`'s `defaultWebuiModelIds()`, which only ever lists built-in models (plus an unrelated admin "overlay" registry) — custom-provider models are never in that default set, regardless of whether they're registered and already answering turns correctly.

   **The fix** (confirmed live — a signed `PUT /v1/admin/scopes/org%3A<org>/webui-models` with body `{"ids":["deepseek-v4.1-flash"]}` returned `200`, and a follow-up signed `GET /v1/admin/scopes/org%3A<org>` confirmed `"webuiModels":["deepseek-v4.1-flash"]`): `register_do_inference_provider()` in `env-lib.sh` now makes a second signed admin call right after registering the provider, setting the org's `webuiModels` allowlist to exactly `[deepseek-v4.1-flash]` (via a new `set-webui-models` command in `gen-secrets.py`, sharing the same signing helpers as the first call — refactored into `sign_admin_request()`/`send_signed_admin_request()`). This is additionally correct, not just a workaround: `app-turn.ts` always unions in the org's own default model (`orgRuntime.modelId`) on top of whatever the allowlist holds, so this doesn't orphan the default model if it were ever different from the allowlist; and setting the allowlist explicitly also closes the side effect from finding 2 above — the fake-OpenAI-branded built-ins are no longer selectable in the web UI picker at all, since they're not in this list either.

### Auto-detecting DigitalOcean's own GenAI automation

Some droplets get `/root/.digitalocean_genai_credentials` dropped on them before first boot by DigitalOcean's own GenAI provisioning automation, a plain `KEY="value"` file:

```sh
MODEL_ACCESS_KEY="doo_v1_..."
INFERENCE_MODEL="some-model-id"
MANAGED_AGENTS_TOKEN="dop_v1_..."
```

(`MANAGED_AGENTS_TOKEN` is a separate, independent piece of automation — see "Auto-detecting an injected Managed Agents token" above — a droplet may get either field, both, or neither.)

When present and populated, `env-lib.sh`'s `detect_do_genai_credentials()` (parsed with `grep`/`cut`, not sourced — no reason to execute a file we didn't write) makes both `setup_wizard.sh` and `001_onboot` skip the model-provider question entirely and always take this path, overriding any droplet env var (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `MODEL_PROVIDER`) that might otherwise have been set. The rest of the pipeline is unchanged — the same `register_do_inference_provider()` registers `$INFERENCE_MODEL` as the custom provider and sets it as the web UI's only enabled model, exactly as for the hardcoded `deepseek-v4.1-flash` default.

The one difference: since `$INFERENCE_MODEL` can be an arbitrary id we have no catalog entry for, `contextWindow`/`maxTokens` aren't guessed — QM's own custom-provider registration treats both as optional (`src/model/custom-providers.ts`, defaults `128_000`/`8_192`), so the auto-detected path passes those same generic defaults (`DO_GENERIC_CONTEXT_WINDOW`/`DO_GENERIC_MAX_TOKENS` in `env-lib.sh`) instead of DeepSeek's actual 1,048,576-token specs.

## Attached DigitalOcean Managed Database

Same pattern as the model-provider auto-detection above, this time for Postgres — following the precedent this repo's own `django-24-04` builder already set for DigitalOcean's DBaaS-attachment automation. Some droplets get `/root/.digitalocean_dbaas_credentials` dropped on them before first boot when a Managed Database is attached at creation time, a plain `KEY="value"` file:

```sh
db_protocol="postgresql"
db_username="doadmin"
db_password="AVNS_..."
db_host="dbaas-db-....db.ondigitalocean.com"
db_port="25060"
db_database="defaultdb"
```

`env-lib.sh`'s `detect_do_dbaas_credentials()` parses it the same defensive way as the genai-credentials file (not sourced; only matches `db_protocol="postgresql"`; `db_database` defaults to `defaultdb` if the file omits it — `django-24-04`'s own parser expects that field but doesn't defend against its absence). When present, `001_onboot` (inside the same one-time `env_is_placeholder POSTGRES_PASSWORD` guard that generates every other one-time secret) calls `bootstrap_do_dbaas()`, which:

1. Waits (bounded retries, not `django-24-04`'s infinite loop) for the attached database to start accepting connections — DO Managed Databases can take a few minutes to provision.
2. Bootstraps a dedicated `qm` user and `qm` database on the cluster using the admin credentials from the file — matching `django-24-04`'s own convention of not running the app against the shared admin account directly, and matching the naming the local bundled Postgres already uses. "Already exists" is tolerated, not fatal, so this is safe even if 001_onboot's own one-shot guard were ever bypassed.
3. Writes `DATABASE_URL` pointing at that dedicated database (`sslmode=require` — DO Managed Databases require TLS, unlike the local bundled Postgres's `sslmode=disable`).

All three steps run via an ephemeral `docker run --rm postgres:16 psql/pg_isready` rather than a host-installed `psql` client — `postgres:16` is already pulled at Packer build time for the local Postgres service, so this needs no new `apt_packages` entry, unlike `django-24-04`'s host-package approach.

**Turning off the local bundled Postgres**: `compose.yml`'s `postgres` service now sits behind a `local-postgres` Compose profile, and `core`'s `depends_on: postgres` carries `required: false`. `001_onboot` writes `COMPOSE_PROFILES=local-postgres` in the normal (no DBaaS) case — identical behavior to before this change — or `COMPOSE_PROFILES=` (blank) when DBaaS is detected, so `docker compose up -d` never starts the local Postgres container at all. Profiles are the right tool here, not just omitting `postgres` from the `docker compose up -d` service list: Compose auto-starts a service's `depends_on` targets regardless of which services were named explicitly, so without the profile gate, naming only `core web-ui portal` would still have pulled `postgres` back in as `core`'s dependency.

**Verified live, and a real gotcha found + fixed**: tested against an actual attached DigitalOcean Managed Database. The bootstrap itself worked (dedicated `qm` user/database created, `DATABASE_URL` written, local Postgres correctly skipped), but `core` crash-looped with `Error: self-signed certificate in certificate chain`. Root cause: `core` uses `pg` (node-postgres), not libpq — and unlike libpq (what `psql`, and so `django-24-04`'s own dbaas bootstrap, actually use), `pg-connection-string` treats `sslmode=require` as an alias for full `verify-full` certificate-chain verification. DigitalOcean's managed-database CA isn't in Node's default trust store, so that verification fails even though the connection is genuinely encrypted. **Fix** (confirmed live — `core` came up clean, listening on `:8080` with `store=postgres`): append `&uselibpqcompat=true` to `DATABASE_URL`, the exact parameter `pg`'s own warning output names for restoring real libpq semantics ("encrypt, don't verify the CA") for `sslmode=require`.

## Docker-in-Docker for app publishing

QM has a "publish a web app" feature: an agent builds something in its sandbox, QM exports the bundle, and a separate "deploy runtime" is supposed to receive and run it. That deploy runtime (`DEPLOY_PROVIDER=docker`, QM's own default when unset) needs a Docker daemon reachable from `core` — and by default there wasn't one, so every droplet's `qm-core` logs have shown `"publishing is unavailable: ... no Docker daemon is reachable from core"` since the very first version of this droplet, just never acted on until now.

**Three real options, with a real security tradeoff between them** — this is why this wasn't wired up by default alongside the other backends:

1. Mount the host's own `/var/run/docker.sock` into `core`. Simplest, but gives anything `core` runs effective root over this entire droplet — every other container (Postgres, web-ui, portal), and the host itself. This directly contradicts this droplet's whole design principle that agent-run code never touches the droplet directly (the same reasoning sandbox backends run externally for).
2. A Docker-in-Docker sidecar — a second, fully separate Docker daemon nested in its own container, isolated from the host's real Docker. **This is what's implemented.**
3. Point `DEPLOY_PROVIDER` at an external platform (`fly`, `aws`, or `porter` — the only other values QM's `src/config.ts` accepts; there is no DigitalOcean-native deploy target). Keeps published apps off this droplet entirely, but needs a whole new external account/credential this droplet doesn't currently collect, and isn't DigitalOcean-native.

**Implementation**: `compose.yml` adds a `dind` service (`docker:27-dind`, `privileged: true` — the real cost of this approach: broad kernel-level access needed to run a nested Docker daemon at all, though a narrower blast radius than the host-socket mount above, since an escape from `dind` doesn't reach the host's real Docker or this stack's other containers). `env.template` sets `DEPLOY_PROVIDER=docker` explicitly (matching QM's own default, but now with a daemon actually behind it) and `scripts/010-qm.sh` pulls the `dind` image at Packer build time alongside the others.

**Verified live, and a real bug found: publishing created containers but they were never reachable.** `dind` came up healthy and `core` could drive it fine (`docker info`, `docker run` all worked), and two published apps were genuinely running inside it — but every request to them failed. Root cause, confirmed by reading QM's own source directly: `src/deploy/docker-deploy-provider.ts` hardcodes `docker run -p 127.0.0.1:<port>:8080 ...` for every published app, with no option to change the bind address, and then returns `{host: "127.0.0.1", port}` as the literal address `core` itself connects to when reverse-proxying traffic to it. That `127.0.0.1` is scoped to whichever network namespace actually ran the `docker run` — `dind`'s own, in the original design — not `core`'s. Confirmed live: `core` got "connection refused" reaching that port both via `127.0.0.1` and via `dind`'s own hostname on the compose network (the bind is loopback-only, not reachable via any other interface, by design of `-p 127.0.0.1:...`). This is an undocumented assumption in QM's own code — confirmed by also reading QM's reference "docker" deploy *target* (`cli/src/backends/docker.ts`, how the `qm` CLI deploys the whole stack when you don't bypass it like this droplet does): it reaches every service at `http://localhost:<port>` too, which only works because that reference topology runs everything co-located, sharing one network namespace. Nothing in either path is configurable — this droplet's fully-containerized `core` (its own isolated network namespace) was never going to satisfy that assumption without a networking change of some kind.

**The fix**: `dind` uses `network_mode: "service:core"` — sharing `core`'s own network namespace specifically, not the host's. This makes a port `dind` publishes to `127.0.0.1` the *same* loopback `core` itself sees, satisfying QM's hardcoded assumption, while `core` stays on the regular compose network exactly as before (zero changes needed for `postgres`/`web-ui`/`portal` reachability — the alternative, giving `core` itself `network_mode: host`, would have cascaded into needing every service `core` talks to reachable via the host loopback too). `core`'s `DOCKER_HOST` changed to `tcp://127.0.0.1:2375` to match. Compose automatically infers `dind`'s dependency on `core`'s container existing first from the `network_mode` reference itself (confirmed in `docker compose config` output: `condition: service_started`, not `service_healthy`) — so `core`'s own `depends_on: dind` was deliberately *removed* rather than kept as a mutual wait, which would have deadlocked (core waiting for dind healthy, dind waiting for core's container to exist). `core` already treats an unreachable Docker daemon as a non-fatal warning, not a startup failure, so this is safe.

One more real bug surfaced building this: the official `docker:dind` image's own entrypoint script auto-injects its own `--host=tcp://0.0.0.0:2375` listener whenever `DOCKER_TLS_CERTDIR=""` is set *and* the first element of `command:` starts with `-` (confirmed by reading `dockerd-entrypoint.sh` directly) — colliding with our own explicit `127.0.0.1:2375` bind on the same port and crash-looping `dind` with "address already in use". Fixed by leading `command:` with the literal `dockerd` argument, which takes the entrypoint's other branch and execs the given arguments as-is.

**Verified end to end, for real** (not just config-validated): brought the actual stack up, confirmed `dind` reaches `healthy`, ran `docker run -p 127.0.0.1:<port>:80 nginx:alpine` through `core`'s own `DOCKER_HOST` exactly as QM's deploy code does, and confirmed `core` can `wget` that port on its own loopback and get a real response back. Reconfirmed isolation still holds throughout: the host's own `docker ps` never shows the nested container, only `core`'s own `docker ps` (via `DOCKER_HOST`) does.

**A second real bug found on a live droplet with this fix deployed: published apps crashed immediately with `Cannot find module '/app/server.js'`.** The network fix above was working correctly — the problem this time was the filesystem. Confirmed by reading `src/deploy/deploy-service.ts` directly: core writes each published app's source to its own `/data/deployments/<id>` (under `config.dataDir`, the `qm-coredata` volume), then asks `dind` to `docker run -v /data/deployments/<id>:/app:ro` for it. `network_mode: service:core` shares the *network* namespace, not the filesystem — `dind` is still a separate container with its own root filesystem, so it resolved that bind-mount path against its own (unrelated, empty) disk, silently created an empty directory, and mounted that instead of finding the real files. **The fix**: mount the same `qm-coredata` volume into `dind` too, at the identical `/data` path — same volume, same path, in both containers, so `dind`'s bind-mount actually finds what `core` wrote. Verified live by reproducing the exact failure (empty `/app`, `MODULE_NOT_FOUND`) and then the fix (`docker run -v /data/deployments/test123:/app:ro ... node server.js` → runs correctly) with the real command QM's deploy code uses.

## Droplet Size

Packer builds with `s-4vcpu-8gb`. Agent turns run externally (DigitalOcean Managed Agents or e2b), so this droplet only needs to carry Postgres plus the three Node services — not agent workloads. The `core` image build itself (cloning the fork + `npm ci` + `docker build`) is a one-time Packer build-time cost and doesn't need to fit in that size envelope at runtime.

## License

This builder configuration follows the same license as the droplet-1-clicks repository. QM licensing is governed by the upstream project (MIT).
