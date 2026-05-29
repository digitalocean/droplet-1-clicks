# Codex Universal 1-Click Security Audit

Audit date: 2026-05-29  
Scope: `codex-universal-24-04/` template + live droplet `45.55.209.142`

## Overall assessment

| Category | Rating |
|----------|--------|
| Network exposure | Good — SSH-only, no web ports |
| Secrets handling | Good — no secrets in image |
| Supply chain | Improved — image pinned by digest in `template.json` |
| Input validation | Improved — `CODEX_ENV_*` allowlist validation on boot |
| Container isolation | Acceptable for dev — root container, rw workspace |
| Documentation | Good — security notes in listing/readme |

**Verdict:** Suitable for Marketplace as a **development environment** with documented caveats. Not suitable as a production runtime without additional hardening.

---

## Live droplet results (45.55.209.142)

Verified before remediations were applied to the template.

| Check | Result |
|-------|--------|
| UFW status | Active; default deny incoming |
| UFW rules | `22/tcp LIMIT` only (IPv4 + IPv6) |
| Listening ports | SSH (22) on all interfaces; DNS stub on localhost only |
| Container port bindings | `{}` (none published) |
| Container privileged | `false` |
| Docker socket mount | Not mounted |
| Container user | `uid=0(root)` |
| `.env` permissions | `600 root:root` (after first boot) |
| `codex-universal.env` template | `644 root:root` |
| Unattended upgrades | Installed (`unattended-upgrades 2.9.1`) |
| SSH | `PermitRootLogin yes` (standard DO 1-click) |

Image digest at audit time:

```
ghcr.io/openai/codex-universal@sha256:905e512f36460e1be4cfedb30928a8a28299edb0fcd5de7998ceaa72d27fe304
```

---

## Controls that pass

- **Minimal firewall** — `ufw limit ssh/tcp` only; no HTTP/HTTPS or Docker API ports (2375/2376)
- **No published container ports** — compose has no `ports:` block
- **No docker.sock mount** — only workspace and read-only entrypoint script
- **No privileged / host network mode**
- **Build-time SSH lockout** — removed on first boot via `001_onboot`
- **No baked-in secrets** — `.env` contains language version pins only
- **OS patching at build** — `apt full-upgrade` during Packer build

---

## Findings and remediations

### High

| ID | Finding | Remediation |
|----|---------|-------------|
| H1 | Unpinned `:latest` image | **Fixed** — `image_digest` in `template.json`; `IMAGE` in `codex-universal.env` |
| H2 | Container runs as root with full dev toolchain | **Accepted** — documented; upstream design for dev environments |

### Medium

| ID | Finding | Remediation |
|----|---------|-------------|
| M1 | Unvalidated droplet env injection into `.env` | **Fixed** — `validate-codex-universal-env.sh` with upstream allowlist |
| M2 | `.env` permissions only set at first boot | **Fixed** — build script removes `.env` from snapshot; `chmod 600` on template; onboot creates `.env` with `600` |
| M3 | Host entrypoint script executed in container | **Accepted** — mounted read-only; document host integrity requirement |
| M4 | Docker can bypass UFW if users add ports | **Documented** in listing/readme security sections |

### Low / Informational

| ID | Finding | Status |
|----|---------|--------|
| L1 | Docker Compose binary downloaded without checksum (common script) | Inherited repo pattern |
| L2 | Root SSH login | Standard DO 1-click; mitigated by UFW limit |
| L3 | Large toolchain inside container | Expected for dev use |

---

## Hardening applied in template

1. **Image digest pinning** — `template.json` → `codex-universal.env` → `docker-compose.yml`
2. **Env validation** — `validate-codex-universal-env.sh` called from `001_onboot`
3. **No `.env` in snapshot** — created from template on first boot only
4. **Docker `security_opt: no-new-privileges:true`**
5. **Security checks in `test-codex-universal.sh`** — UFW, `.env` perms, no ports, non-privileged, no docker.sock

---

## Verification commands

On a deployed droplet:

```bash
/opt/codex-universal/test-codex-universal.sh
/opt/codex-universal/codex-universal-version.sh
ufw status verbose
docker inspect codex-universal --format 'Privileged={{.HostConfig.Privileged}} Ports={{json .HostConfig.PortBindings}}'
```

To update the pinned digest for a new snapshot:

1. Pull and inspect: `docker pull ghcr.io/openai/codex-universal:latest && docker inspect ... --format='{{index .RepoDigests 0}}'`
2. Update `image_digest` in `template.json` and `IMAGE` / `IMAGE_DIGEST` in `codex-universal.env`
3. Rebuild with Packer

---

## Out of scope

- Running container as non-root
- Read-only root filesystem
- Sandboxing compilers/toolchains inside the container

These would conflict with the upstream codex-universal development image design.
