# Matrix

Matrix is an open source, decentralized, federated chat system. These are the
build scripts for our 1-click app! :D

https://marketplace.digitalocean.com/apps/matrix-synapse-backend

## Create your new server

Keep in mind when selecting a monthly plan that the more resources you can
provide, the better the chat quality will be. 2GB+ RAM is highly recommended.

## Dependencies

- A new domain you'd like to use exclusively for Matrix (it is recommended
  and also very cute to buy a .town, .space, or similar domain for this purpose)
- openssh (or putty)
- 5 minutes

## Finishing Setup

1. Login to your droplet via `ssh root@your_droplet_public_ipv4`
2. Run ./finish-setup
3. When directed, set up your DNS records
4. Read /root/README.txt
5. ???
6. Profit!

## Building the image

```
export DIGITALOCEAN_TOKEN=your_do_token
packer build matrix.json
```

## Supporting Matrix

If you love Matrix as much as we do, please consider supporting their project!
See the "Support Matrix" section of https://www.matrix.org/ for more details.
