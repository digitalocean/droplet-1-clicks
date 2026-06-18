# Pocketbase Packer scripts for Cloud Marketplace Image

This repo contains scripts used to create a marketplace one-click install image. The image can be used to stand up a fully configured Pocketbase droplet for the DigitalOcean Marketplace.

### Building the image

First, you will need to install Packer on your system.  On a Mac, use 

```
brew install packer
```

This builder uses the new hcl format.  Pass the version of PocketBase you wish to use, ie. `0.10.0`

```
APP_VERSION={target-version} packer build --only 'digitalocean.ubuntu-2204' .
```

Once complete, Packer has created a new image in your account that you can use to create a droplet running the described version of PocketBase.

Note:

You will need to get a personal access token from Digital Ocean, and set it in your environment as follows:

```
export DIGITALOCEAN_TOKEN=dop_your-token
```



