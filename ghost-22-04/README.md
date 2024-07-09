# Ghost

## Prereqs

* [make](https://www.gnu.org/software/make/)
* [Packer](https://www.packer.io/intro/index.html)

## Build Automation with Packer

[Packer](https://www.packer.io/intro/index.html) is a tool for creating images from a single source configuration. Using this Packer template reduces the entire process of creating, configuring, validating, and snapshotting a build Droplet to a single command:

```
make build
```

The Packer build command can also be run manually.

```
packer build ghost-image.json
```

### Usage

To run the Packer build that this template uses by default, you'll need to [install Packer](https://www.packer.io/intro/getting-started/install.html) and [create a DigitalOcean personal access token](https://www.digitalocean.com/docs/api/create-personal-access-token/) and set it to the `DIGITALOCEAN_API_TOKEN` environment variable. Running `packer build ghost-image.json` without any other modifications will create a build Droplet configured with Ghost, clean and verify it, then power it down and snapshot it.

> ⚠️ The image validation script in `scripts/999-img_check.sh` is copied from the [top-level `scripts` directory](../scripts) in this repository. The top-level location is the script's canonical source, so make sure you're using the latest version from there.

To start adapting this configuration for your own image, you can customize some variables in `ghost-image.json`:

* `do_api_token` defines the DO API Token used to create resources via DigitalOcean's API. By default it is set to the value of the `DIGITALOCEAN_API_TOKEN` environment variable.
* `image_name` defines the name of the resulting snapshot, which by default is `ghost-snapshot-` with a UNIX timestamp appended.
* `node_version` defines the apt repo to use to install Node JS (eg. `node_16.x`, `node_18.x` etc)

You can also modify these variables at runtime by using [the `-var` flag](https://www.packer.io/docs/templates/user-variables.html#setting-variables).

### Configuration Details

By using [Packer's DigitalOcean Builder](https://www.packer.io/docs/builders/digitalocean.html) to integrate with the [DigitalOcean API](https://developers.digitalocean.com/), this configuration fully automates Ghost image creation.

This configuration uses Packer's [file provisioner](https://www.packer.io/docs/provisioners/file.html) to upload complete directories to the Droplet. The contents of `files/var/` will be uploaded to `/var/`. Likewise, the contents of `files/etc/` will be uploaded to `/etc/`. One important thing to note about the file provisioner, from Packer's docs:

> The destination directory must already exist. If you need to create it, use a shell provisioner just prior to the file provisioner in order to create the directory. If the destination directory does not exist, the file provisioner may succeed, but it will have undefined results.

This configuration also uses Packer's [shell provisioner](https://www.packer.io/docs/provisioners/shell.html) to run scripts from the `/scripts` directory and update installed APT packages using an inline task.

After making changes to the configuration, packer validate command.

```
make validate
```

Learn more about using Packer in [the official Packer documentation](https://www.packer.io/docs/index.html).

# Copyright & License

Copyright (c) 2013-2023 Andrew Starr-Bochicchio & Ghost Foundation - Released under the [MIT license](LICENSE). Ghost and the Ghost Logo are trademarks of Ghost Foundation Ltd. Please see our [trademark policy](https://ghost.org/trademark/) for info on acceptable usage.
