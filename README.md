# 1-Click Droplet Packer Build templates

These are the Packer build templates for DigitalOcean Marketplace 1-clicks.

## Prereqs

* [make](https://www.gnu.org/software/make/)
* [Packer](https://www.packer.io/intro/index.html)

## Build Automation with Packer

[Packer](https://www.packer.io/intro/index.html) is a tool for creating images from a single source configuration. Using this Packer template reduces the entire process of creating, configuring, validating, and snapshotting a build Droplet to a single command:

```sh
make build-{{image-name}}
```

The Packer build command can also be run manually.

```sh
packer build {{image-name}}/template.json
```

### Usage

To run the Packer build that this template uses by default, you'll need to [install Packer](https://www.packer.io/intro/getting-started/install.html) and [create a DigitalOcean personal access token](https://www.digitalocean.com/docs/api/create-personal-access-token/) and set it to the `DIGITALOCEAN_API_TOKEN` environment variable. Running `packer build {{image-name}}/template.json` without any other modifications will create a build Droplet configured with that 1-Click, clean it, power it down, and snapshot it.

> ⚠️ The image validation script in `common/scripts/999-img_check.sh` is copied from the [marketplace-partners repo](https://github.com/digitalocean/marketplace-partners). The marketplace-partners repo is the script's canonical source, so make sure you're using the latest version from there. Update it by running `make update-scripts`.

### Creating a new 1-Click

To start adapting this configuration for your own image, you can create a scaffold using the command `make {{image-name}}` which will create a directory `{{image-name}}` with a basic Packer build config.

The following variables are required.

* `do_api_token` defines the DO API Token used to create resources via DigitalOcean's API. By default it is set to the value of the `DIGITALOCEAN_API_TOKEN` environment variable.
* `image_name` defines the name of the resulting snapshot, which by default is `{{image-name}}-snapshot-` with a UNIX timestamp appended.
* `application_name` defines the name of the 1-Click in the Marketplace. It is saved to /var/lib/digitalocean/application.info
* `application_version` defines the version of the most prominent software installed, usually what gives the 1-Click its name. If you are installing the latest version of software, this can be a command (See the nodejs 1-Click). It is saved to /var/lib/digitalocean/application.info. Some applications are a bundle of applications and don't have a specific version (See the LAMP 1-Click).

If a 1-Click is installing a particular version of software through a script and not apt, include a variable for the version. (See the nodejs 1-Click)

You can also modify these variables at runtime by using [the `-var` flag](https://www.packer.io/docs/templates/user-variables.html#setting-variables).

### Configuration Details

By using [Packer's DigitalOcean Builder](https://www.packer.io/docs/builders/digitalocean.html) to integrate with the [DigitalOcean API](https://developers.digitalocean.com/), this configuration fully automates image creation.

This configuration uses Packer's [file provisioner](https://www.packer.io/docs/provisioners/file.html) to upload complete directories to the Droplet. The contents of `files/var/` will be uploaded to `/var/`. Likewise, the contents of `files/etc/` will be uploaded to `/etc/`. One important thing to note about the file provisioner, from Packer's docs:

> The destination directory must already exist. If you need to create it, use a shell provisioner just prior to the file provisioner in order to create the directory. If the destination directory does not exist, the file provisioner may succeed, but it will have undefined results.

This configuration also uses Packer's [shell provisioner](https://www.packer.io/docs/provisioners/shell.html) to run scripts from the `/scripts` directory and update installed APT packages using an inline task.

After making changes to the configuration, packer validate command.

```sh
make validate-{{image-name}}
```

Learn more about using Packer in [the official Packer documentation](https://www.packer.io/docs/index.html).

### Debugging

* [Debugging Documentation](https://www.packer.io/docs/debugging)

Get additional log information by setting the `PACKER_LOG` environment variable to any value other than "".

```sh
PACKER_LOG=1 packer build {{image-name}}/template.json
```

Add the `-debug` flag to prompt the user to continue at every Packer build step. The `-debug` flag also generates a .pem file that can be used to ssh into the droplet to inspect the current state.

```sh
packer build -debug {{image-name}}/template.json
```

Add the `-on-error=ask` flag. When the build fails, it will prompt the user to either retry, cleanup, or abort the build.

```sh
packer build -on-error=ask {{image-name}}/template.json
```

## Notes

* MySQL and phpMyAdmin use the same files and build script. They have separate template.json files to set different image names and application tag info.
