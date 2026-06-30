# droplet-1-clicks directory structure

Each Marketplace droplet 1-click lives in its own folder at the repo root, typically named `<app>-24-04` (Ubuntu 24.04).

## Per-app layout

```
<app>-24-04/
├── template.json      # Packer template (DigitalOcean builder + provisioners)
├── listing.md         # Marketplace catalog copy
├── readme.md          # Builder documentation for developers
├── files/             # Static files copied onto the image (etc/, var/, …)
│   ├── etc/
│   └── var/
└── scripts/           # Provisioner shell scripts (builder, onboot, helpers)
```

## Scaffold

Copy [`_template/`](https://github.com/digitalocean/droplet-1-clicks/tree/master/_template) when creating a new app. Replace `{{TODO}}` / `{{IMAGE_LABEL}}` placeholders in `template.json`.

## Packer file provisioners

Templates typically copy:

- `common/files/var/` → `/var/` on the droplet
- `<app>-24-04/files/etc/` → `/etc/`
- Scripts from `<app>-24-04/scripts/` via shell provisioners

See [`_template/template.json`](https://github.com/digitalocean/droplet-1-clicks/blob/master/_template/template.json) for the canonical provisioner order (`cloud-init status --wait` first).

## Reference implementations

| Pattern | Example dirs |
|---------|----------------|
| Docker-based app | `campfire-24-04/`, `coolify-24-04/` |
| Classic LAMP/stack | `wordpress-24-04/`, `lemp-24-04/` |
| Minimal hello world | `hello-world-24-04/` |

## Base image

New 24.04 builders use `"image": "ubuntu-24-04-x64"` in the DigitalOcean builder block (see `campfire-24-04/template.json`). Older `_template` may still reference 20.04 — use 24.04 for new work.

## Naming

- Folder name: lowercase, hyphens, OS suffix (`myapp-24-04`).
- `application_name` / `image_name` variables in `template.json` should match product naming conventions.
