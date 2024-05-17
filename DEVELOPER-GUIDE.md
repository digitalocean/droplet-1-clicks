# 1-Click App Development with Packer

This guide outlines the essential files and considerations for creating a 1-Click app deployment using Packer.

## Basic 1-Click Setup

**Required Files:**

* `example-1-click/template.json`: This file defines the packages to install, image build configuration, and installation locations.
* `example-1-click/scripts/installer.sh`: This script performs the actual application installation on the Droplet.
* `example-1-click/files/etc/update-motd.d/99-one-click`: This file contains basic instructions for users upon first login to the Droplet.

> **Note:** To quickly get started, a sample template is available at `droplet-1-clicks/_template/template.json` containing the required DigitalOcean packer configuration.

#### DigitalOcean API Token

Open your terminal or command prompt.
Set the API token as an environment variable:

```bash
export DIGITALOCEAN_API_TOKEN=your_api_token_here
```

Replace your_api_token_here with the actual API token you generated.

* Within your Packer template `droplet-1-clicks/_template/template.json`, ensure that the DigitalOcean API token variable is set to {{user do_api_token}}.
This token will be retrieved from the environment variable DIGITALOCEAN_API_TOKEN during the build process.
Ensure that the appropriate permissions are granted to the API token to perform the necessary actions during the build.

> **Note:** > The snapshot created by Packer will be available to the team associated with the DigitalOcean account that was used to generate the API token and initiate the Packer build process.
> When you log in to your DigitalOcean account and navigate to the "Images" section, the snapshot will be visible to all teams within the account. However, only users with appropriate permissions (such as team owners or members with image management permissions) will be able to manage or use the snapshot.
If you want the snapshot to be available to a specific team or project within your DigitalOcean account, you can manually share the snapshot with that team after it has been created. This can be done through the DigitalOcean control panel by adjusting the sharing and permissions settings for the snapshot.

**Additional Considerations:**
For a very basic 1-Click, above is all you need. However, there might be scenarios where:

**Startup Script:**

    - You need to run a script to setup something when the droplet starts rather than during the build process.
    - `example-1-click/files/var/lib/cloud/scripts/per-instance/001_onboot`: This script executes commands during Droplet startup.

> **Note:** The `droplet-1-clicks/_template` also contains a sample 001_onboot script `droplet-1-clicks_template/files/var/lib/cloud/scripts/per-instance/001_onboot` script

**Systemd Services:**

    - If you need some systemd services to be installed as part of the build process, you add them under `example-1-click/files/etc/systemd/system` . Notice that the path after `example-1-click/files` must be exactly how you want it in the droplet. Since we want the systemd services under `/etc/systemd/system` we did the same. You can then enable/start these services in the `installer.sh` or `001_onboot` .
    - The directory structure within `example-1-click/files` mirrors the desired structure on the built Droplet (e.g., `/etc/systemd/system` for systemd services).

**Application Configuration:**

    - `example-1-click/files/etc/nginx/sites-available/`: This directory stores configuration files for services like Nginx (the path may vary depending on your application).
    - Example: `sites.conf` for Nginx configuration, located at `/etc/nginx/sites-available/` on the Droplet.

**Additional Files:**

    - `example-1-click/files/var/lib/digitalocean/`: This directory holds any files referenced by scripts like `001_onboot`.

**Packer Configuration (`template.json`):**

```json
  [
    {
      "type": "file",
      "source": "example-1-click/files/etc/",
      "destination": "/etc/"
    },
    {
      "type": "file",
      "source": "example-1-click/files/var/",
      "destination": "/var/"
    },
    // ... Add more file copy blocks as needed
    {
      "type": "shell",
      "environment_vars": [
        "application_name={{user `application_name`}}",
        "application_version={{user `application_version`}}",
        "DEBIAN_FRONTEND=noninteractive",
        "LC_ALL=C",
        "LANG=en_US.UTF-8",
        "LC_CTYPE=en_US.UTF-8"
      ],
      "scripts": [
        "example-1-click/scripts/installer.sh"

        // Recommended scripts for enhanced security
        "common/scripts/014-ufw-nginx.sh",
        "common/scripts/018-force-ssh-logout.sh",
        "common/scripts/020-application-tag.sh",
        "common/scripts/900-cleanup.sh"

        // ... Add additional scripts to execute during build time
      ]
    },

  ]
```

You can use the same block to install files in other places if your 1-Click requires it.

**Security Enhancements:**

**Environment Variables in `template.json`:**
    - Define environment variables for application name, version, and other configuration details.
    - Use interpolation (`{{user ... }}`) to access user-provided values.

**Additional Security Scripts:**

You can add more scripts under the "scripts" property to execute other scripts at build time to make your Droplet 1-Click secure.
    - `common/scripts/014-ufw-nginx.sh`: Enables SSH port 22 and allows Nginx traffic through the firewall.
    - `common/scripts/018-force-ssh-logout.sh`: Prevents user login until `001_onboot` completes execution.
    - `common/scripts/020-application-tag.sh`: Writes application information to the Droplet.
    - `common/scripts/900-cleanup.sh`: Removes temporary passwords or SSH keys used during the build process.

> **Note:** After using the `common/scripts/018-force-ssh-logout.sh` script, add the following to your `001_boot` script to be able to login when the droplet initialization is complete.

```bash
    # Remove the ssh force logout command
    sed -e '/Match User root/d' \
        -e '/.*ForceCommand.*droplet.*/d' \
        -i /etc/ssh/sshd_config

    systemctl restart ssh
```
