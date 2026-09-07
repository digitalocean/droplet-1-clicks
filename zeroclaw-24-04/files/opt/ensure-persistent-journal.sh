#!/bin/bash
# Enable persistent systemd journal so journalctl -u zeroclaw works on DO droplets.
set -euo pipefail

mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal >/dev/null 2>&1 || true

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/persistent.conf <<'EOF'
[Journal]
Storage=persistent
EOF

systemctl restart systemd-journald >/dev/null 2>&1 || true
