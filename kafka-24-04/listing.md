# Apache Kafka 1-Click Application

Deploy [Apache Kafka](https://kafka.apache.org) as a single-node broker in **KRaft** combined mode (no ZooKeeper). The image installs Kafka 4.3.1 on Ubuntu 24.04 with TLS and SCRAM-SHA-256 on the public listener.

## System Components

| Component | Details |
|-----------|---------|
| Ubuntu | 24.04 LTS |
| OpenJDK | 17 (required by Kafka 4.x brokers) |
| Apache Kafka | 4.3.1 (`kafka_2.13-4.3.1`), KRaft broker + controller |
| systemd | `kafka.service` |
| UFW | Firewall (SSH 22, Kafka SASL_SSL 9093) |

## System Requirements

**Minimum Droplet size: `s-2vcpu-4gb` (4 GB RAM / 2 vCPU).** The Packer builder and Marketplace listing use this size. KRaft combined mode keeps metadata in the same JVM as the broker; heap is capped at 50% of RAM so first boot cannot OOM-lock SSH.

| Use case | Recommended |
|----------|-------------|
| Marketplace minimum / tutorial | 4 GB RAM, 2 vCPU |
| Light production (single node) | 8 GB+ RAM, 4 vCPU |

## Getting Started

1. **Create a Droplet** from this 1-Click image (use at least **4 GB RAM / 2 vCPU**).
2. **Wait for first boot** — SSH is locked until `/var/lib/cloud/scripts/per-instance/001_onboot` finishes (TLS certs, KRaft format, SCRAM user `doadmin`, `kafka.service`). SSH is unlocked even if Kafka setup fails.
3. **SSH in** and follow the MOTD. Local plaintext is on `localhost:9092`. Public clients use `<droplet-ip>:9093` with SASL_SSL.
4. **Copy client credentials** from `/opt/kafka/one-click-ssl/example.librdkafka.config`, the CA cert `/opt/kafka/one-click-ssl/ca.crt`, and `/opt/kafka/one-click-ssl/.keystore_password` for Java KeyStore clients.

**Security note:** Port 9093 is open to the internet and requires the generated `doadmin` SCRAM password. Do not send credentials over the localhost plaintext listener from off-box. `allow.everyone.if.no.acl.found` is `true`, so any additional SCRAM user you create is an admin until you set ACLs.

**Public IP changes:** First boot bakes the Droplet public IP into `advertised.listeners` and the self-signed certificate SANs. Reassigning a Reserved IP or restoring to a new Droplet makes remote TLS clients fail hostname verification until you regenerate the cert and rewrite `server.properties`.

### Listeners

| Address | Protocol | Use |
|---------|----------|-----|
| `127.0.0.1:9092` | PLAINTEXT, no auth | On-Droplet tools (`kafka-topics.sh`, console producer/consumer) |
| `0.0.0.0:9093` | SASL_SSL + SCRAM-SHA-256 | Remote clients (UFW allowed) |
| `127.0.0.1:9094` | PLAINTEXT | KRaft controller (local only, not for clients) |

## Managing Kafka

### Start, stop, restart, status

```bash
systemctl start kafka
systemctl stop kafka
systemctl restart kafka
systemctl status kafka
```

Logs: `/var/log/kafka/kafka.log` and `journalctl -u kafka`.

### Update

This image is rebuilt for Marketplace Autoupdate from `application_version` in `template.json`. To change the version on a **new** image:

1. Set `application_version` in `kafka-24-04/template.json` (for example `4.3.1`).
2. Rebuild with Packer (`make build-kafka-24-04` or `packer build -var application_version=4.3.1 kafka-24-04/template.json`). The installer fetches Apache's official SHA-512 for that version.

In-place upgrades of an existing Droplet are not supported by this 1-Click. Stand up a new Droplet from the updated snapshot and migrate producers/consumers.

## Data Locations

| Path | Purpose |
|------|---------|
| `/opt/kafka` | Kafka install and CLI tools |
| `/opt/kafka/config/server.properties` | Broker / KRaft config (written on first boot) |
| `/opt/kafka/one-click-ssl/` | TLS material, SCRAM client config, client README |
| `/opt/kafka/one-click-ssl/example.librdkafka.config` | Public-listener username and password |
| `/opt/kafka/one-click-ssl/.keystore_password` | Password for the Java KeyStores in that directory |
| `/var/lib/kafka` | KRaft metadata and topic logs |
| `/var/log/kafka` | rsyslog capture of `kafka.service` |

## Support

- [Apache Kafka documentation](https://kafka.apache.org/documentation/)
- [KRaft operations](https://kafka.apache.org/documentation/#kraft)
- [DigitalOcean Community](https://www.digitalocean.com/community)
