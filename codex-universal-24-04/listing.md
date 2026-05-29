# Codex Universal 1-Click Application

Run [OpenAI codex-universal](https://github.com/openai/codex-universal) on DigitalOcean — the reference Docker image for the multi-language development environment used in [OpenAI Codex](https://platform.openai.com/docs/codex). Debug, customize, and develop in an environment that closely mirrors Codex cloud workspaces.

## What is Codex Universal?

`codex-universal` is OpenAI's base development container. It ships pre-built toolchains for modern software development so you can reproduce Codex-style environments on your own infrastructure.

- **Multi-language runtimes** — Python, Node.js, Rust, Go, Ruby, PHP, Java, Swift, and more
- **Version pinning** — Select language versions via `CODEX_ENV_*` environment variables
- **Persistent workspace** — `/root/workspace` on the host is mounted at `/workspace` in the container
- **Docker-based** — Official image from `ghcr.io/openai/codex-universal`
- **SSH workflow** — SSH into the droplet and open an interactive shell inside the container

## Key Features

- Approximate the OpenAI Codex cloud dev environment on a DigitalOcean Droplet
- Pre-configured default language versions (Python 3.12, Node 20, Rust 1.87, Go 1.23, and others)
- Override runtimes via `/opt/codex-universal/.env` or droplet environment variables at create time
- Helper scripts to start, stop, restart, update, and enter the environment
- Includes bun, Bazelisk, Erlang, and Elixir in the upstream image

## System Requirements

The codex-universal image is large and includes many language toolchains. Use these Droplet sizes as a guide:

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Minimum | 4 GB | 2 vCPU | 50 GB |
| Recommended | 8 GB | 4 vCPU | 80 GB |

## Included System Components

- **Ubuntu 24.04 LTS** — Base operating system
- **Docker & Docker Compose** — Container runtime
- **Codex Universal** — `ghcr.io/openai/codex-universal:latest`
- **systemd service** — `codex-universal.service` keeps the dev container running
- **UFW Firewall** — SSH only (rate-limited)

## Getting Started

### 1. Deploy the Droplet

1. Select this 1-Click App from the DigitalOcean Marketplace
2. Choose at least **4 GB RAM** (8 GB recommended)
3. Add your SSH key for secure access
4. Optionally set `CODEX_ENV_*` droplet environment variables to customize language versions
5. Create the Droplet

### 2. Wait for First Boot

First boot starts the Codex Universal container and runs language runtime setup. This can take several minutes.

### 3. SSH In

```bash
ssh root@your-droplet-ip
```

### 4. Enter the Development Environment

```bash
/opt/codex-universal/shell-codex-universal.sh
```

Inside the container, your workspace is at `/workspace`. On the host, the same files live in `/root/workspace`.

### 5. Work on Your Project

```bash
# On the host (before or after entering the shell)
cd /root/workspace
git clone https://github.com/your-org/your-repo.git

# Enter the Codex environment
/opt/codex-universal/shell-codex-universal.sh

# Inside the container
cd /workspace/your-repo
python3 --version
node --version
rustc --version
```

## Configuring Language Runtimes

Edit `/opt/codex-universal/.env` and set `CODEX_ENV_*` variables, then restart:

```bash
/opt/codex-universal/restart-codex-universal.sh
```

Supported variables (see [upstream docs](https://github.com/openai/codex-universal#configuring-language-runtimes)):

| Variable | Example |
|----------|---------|
| `CODEX_ENV_PYTHON_VERSION` | `3.12` |
| `CODEX_ENV_NODE_VERSION` | `20` |
| `CODEX_ENV_RUST_VERSION` | `1.87.0` |
| `CODEX_ENV_GO_VERSION` | `1.23.8` |
| `CODEX_ENV_SWIFT_VERSION` | `6.2` |
| `CODEX_ENV_RUBY_VERSION` | `3.4.4` |
| `CODEX_ENV_PHP_VERSION` | `8.4` |
| `CODEX_ENV_JAVA_VERSION` | `21` |

You can also pass these as droplet environment variables when creating the Droplet.

## Managing the Service

| Action | Command |
|--------|---------|
| Enter shell | `/opt/codex-universal/shell-codex-universal.sh` |
| Start | `/opt/codex-universal/start-codex-universal.sh` |
| Stop | `/opt/codex-universal/stop-codex-universal.sh` |
| Restart | `/opt/codex-universal/restart-codex-universal.sh` |
| Update image | `/opt/codex-universal/update-codex-universal.sh` |
| Status | `/opt/codex-universal/status-codex-universal.sh` |
| Version info | `/opt/codex-universal/codex-universal-version.sh` |

Or use systemd directly:

```bash
systemctl status codex-universal
systemctl restart codex-universal
journalctl -u codex-universal -f
```

## Updating

Pull the pinned image and restart:

```bash
/opt/codex-universal/update-codex-universal.sh
```

The image is pinned by digest (`IMAGE` and `IMAGE_DIGEST` in `/opt/codex-universal/.env`) for reproducible builds. To adopt a newer upstream release, update the digest in the env file and rebuild the 1-click snapshot, or edit `IMAGE` / `IMAGE_DIGEST` manually after verifying the new digest.

## Security Notes

- Only SSH (port 22) is exposed by default; UFW rate-limits SSH connections
- No web interface or HTTP ports are opened
- Docker image is pinned by digest at build time (see `IMAGE_DIGEST` in `.env`)
- `CODEX_ENV_*` droplet environment variables are validated against upstream supported versions on first boot
- Store secrets and API keys outside the image; configure them at runtime
- The dev container runs as root — suitable for development, not for production
- **Docker/UFW caveat:** If you add `ports:` to `docker-compose.yml`, Docker may expose those ports regardless of UFW. Keep the default compose file unchanged unless you understand the exposure.
- Run `/opt/codex-universal/test-codex-universal.sh` to verify runtime and security checks

See [SECURITY.md](SECURITY.md) for the full security audit.

## Resources

- [codex-universal on GitHub](https://github.com/openai/codex-universal)
- [OpenAI Codex documentation](https://platform.openai.com/docs/codex)
- [DigitalOcean Droplet documentation](https://docs.digitalocean.com/products/droplets/)

## License

Codex Universal is maintained by OpenAI. See the [upstream repository](https://github.com/openai/codex-universal) for license terms.
