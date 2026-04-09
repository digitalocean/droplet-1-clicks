# Ghost (Ubuntu 24.04)

This 1-click builds an image with **Ubuntu 24.04 LTS**, **Ghost 6.x**, **Node.js 22** (via NodeSource), MySQL, nginx (managed by Ghost CLI), Postfix, and fail2ban.

## Prereqs

* [make](https://www.gnu.org/software/make/)
* [Packer](https://www.packer.io/intro/index.html)

## Build Automation with Packer

[Packer](https://www.packer.io/intro/index.html) drives creating, configuring, validating, and snapshotting the build Droplet. Template file: [`template.json`](template.json).

### Running Packer (repository root)

Provisioner paths are relative to the **repository root**. From the repo root:

```sh
packer validate ghost-24-04/template.json
packer build ghost-24-04/template.json
```

Or use the root Makefile:

```sh
make validate-ghost-24-04
make build-ghost-24-04
```

From this directory (`ghost-24-04/`), `make build` and `make validate` run the same commands by changing to the parent directory first (see [`Makefile`](Makefile)).

### Usage

You need [Packer](https://www.packer.io/intro/getting-started/install.html) and a [DigitalOcean personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) exported as `DIGITALOCEAN_API_TOKEN`. A successful `packer build` creates a temporary Droplet, provisions Ghost and dependencies, runs cleanup, powers off, and saves a snapshot.

> The image validation script `999-img_check.sh` is maintained under [`common/scripts/`](../common/scripts/) in this repository (synced from [marketplace-partners](https://github.com/digitalocean/marketplace-partners)); use the repo copy as canonical.

### Variables (`template.json`)

* `do_api_token` — API token; defaults to `DIGITALOCEAN_API_TOKEN`.
* `image_name` — Snapshot name; default pattern includes `ghost-24-04-1click-` and a timestamp.
* `ghost_version` — Ghost npm package version installed on first boot (default matches Ghost 6.x).
* `ghost_cli_version` — Global `ghost-cli` version.
* `node_version` — NodeSource stream (e.g. `22.x` for Node 22 LTS).

Override at build time with [Packer `-var`](https://developer.hashicorp.com/packer/docs/templates/hcl/variables).

### Builder Droplet size

[`template.json`](template.json) uses DigitalOcean size **`s-1vcpu-2gb`** (1 vCPU, 2 GB RAM) for the **build** Droplet.

[Ghost’s hosting documentation](https://ghost.org/docs/hosting/) states a supported production server needs **at least 1 GB** of memory for Ghost itself. This image is larger because:

* The 1-click runs **Ghost, MySQL, nginx, Postfix, fail2ban, and the OS** on one Droplet—RAM is shared across all services, not only Node/Ghost.
* **Provisioning and first boot** (`ghost install`, database setup, migrations) use more memory than steady-state serving; extra RAM avoids OOM or heavy swapping during setup.
* Marketplace images are typically sized **above the app’s bare minimum** so new Droplets from the snapshot are reliable without an immediate resize.

### Configuration details

This configuration uses [Packer’s DigitalOcean builder](https://developer.hashicorp.com/packer/plugins/builders/digitalocean) and [file](https://developer.hashicorp.com/packer/docs/provisioners/file) / [shell](https://developer.hashicorp.com/packer/docs/provisioners/shell) provisioners. Contents of `files/var/`, `files/etc/`, and `files/opt/` are uploaded to matching paths on the image; see Packer’s notes on destination directories in the provisioner docs.

After changes, validate from the repo root:

```sh
make validate-ghost-24-04
# or: cd ghost-24-04 && make validate
```

More detail: [Packer documentation](https://developer.hashicorp.com/packer/docs).
