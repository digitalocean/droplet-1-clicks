# Apache Kafka 1-Click Droplet

Packer template for a DigitalOcean Marketplace 1-Click image that runs [Apache Kafka](https://kafka.apache.org) 4.3.1 in **KRaft combined mode** (broker + controller, no ZooKeeper) on Ubuntu 24.04.

## What's Included

- **Apache Kafka** at the version in `application_version` (`template.json`), currently `4.3.1`
- **OpenJDK 17**
- **systemd** unit `kafka.service` (rendered on first boot; heap capped at 50% of RAM)
- **UFW** allowing SSH (22) and Kafka SASL_SSL (9093) only
- First-boot TLS (self-signed CA) and SCRAM-SHA-256 user `doadmin` with a random password

## Droplet Size

Build and recommend **`s-2vcpu-4gb`** (4 GB RAM / 2 vCPU). First-boot heap is half of physical RAM so the OS and KRaft native memory keep enough headroom to finish `001_onboot` and unlock SSH.

## Building

From the `droplet-1-clicks` repository root:

```bash
export DIGITALOCEAN_API_TOKEN="your-token"

# Packer 1.7+ plugins (DigitalOcean builder + Ansible provisioner)
packer plugins install github.com/digitalocean/digitalocean
packer plugins install github.com/hashicorp/ansible

# Ansible collection used by the playbook (pam_limits, ufw)
ansible-galaxy collection install -r kafka-24-04/ansible/requirements.yml

make validate-kafka-24-04
make build-kafka-24-04
```

Or with Packer directly:

```bash
packer validate kafka-24-04/template.json
packer build kafka-24-04/template.json
```

Autoupdate (and manual version bumps) must pass **both** the Marketplace pin and the Apache SHA-512 (128 lowercase hex chars, no `sha512:` prefix):

```bash
packer build \
  -var 'application_version=4.3.1' \
  -var 'kafka_sha512=c7d7b2318cb51aa0c61d3246a51c349210073c5c9b754947ef965a439f2f939e8600f204e134a75ac31faf3829c9370960ef7c6a9886c8a1dbf0339a21f4c54c' \
  kafka-24-04/template.json
```

## How It Works

1. Packer waits for cloud-init, then runs `kafka-24-04/ansible/kafka.yml` as root.
2. Ansible installs OpenJDK 17 JRE, downloads `kafka_2.13-<version>.tgz` from Apache (pinned `kafka_sha512` from `template.json`, falling back to the archive URL), and ships first-boot templates under `/opt/kafka/do-templates`.
3. `application_version` and `kafka_sha512` are passed as `--extra-vars` so Autoupdate can change the tarball without editing Ansible defaults. Always update the digest when the version changes.
4. `018-force-ssh-logout.sh` blocks SSH until per-instance setup finishes.
5. On first boot, `001_onboot` writes `server.properties`, formats KRaft storage (`kafka-storage.sh format --standalone`), enables `kafka.service`, and writes `/opt/kafka/one-click-ssl/`.

## Files

| Path | Purpose |
|------|---------|
| `template.json` | Packer build template (`application_version` + `kafka_sha512` pins) |
| `ansible/kafka.yml` | Playbook (OpenJDK + Kafka roles) |
| `ansible/requirements.yml` | `community.general` collection |
| `ansible/roles/kafka/` | Download, UFW, MOTD, onboot, KRaft templates |
| `ansible/roles/openjdk/` | OpenJDK 17 |
| `listing.md` | Marketplace catalog copy |
| `README.md` | This file |

## Smoke Test Checklist

After creating a Droplet from the snapshot:

- [ ] Packer build finished with no interactive/TTY hang
- [ ] After first boot, `systemctl is-active kafka` is active
- [ ] Topic list works: `/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list`
- [ ] `/opt/kafka/one-click-ssl/example.librdkafka.config` contains `sasl.username=doadmin` and `sasl.password` (mode `0600`)
- [ ] MOTD prints those credentials and the config path
- [ ] UFW allows only 22 and 9093 (`ufw status`); 9094 is not public
- [ ] No `zookeeper.service` unit is present
