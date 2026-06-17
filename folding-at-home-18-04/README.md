# Folding@home image

https://marketplace.digitalocean.com/apps/foldinghome

## Setup
Install [packer](https://www.packer.io/intro/getting-started/install.html)

### Build
```
DIGITALOCEAN_TOKEN=<your api token> packer build ./folding-at-home-image.json
```

This task will perform all steps (upload files, run scripts, install packages,
clean up build system, power off) to prepare your droplet for snapshot.

## Development

See the [Marketplace Partners guide](https://github.com/digitalocean/marketplace-partners/tree/master/fabric)

## Donations

If you like this tool, consider donating to the authors from which this work
is derived:
https://foldingathome.org/about/donate/