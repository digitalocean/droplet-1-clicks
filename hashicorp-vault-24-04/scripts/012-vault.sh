#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

resolve_latest_vault_version() {
    curl -fsS https://api.releases.hashicorp.com/v1/releases/vault/latest | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['version'])"
}

VAULT_REQUESTED_VERSION="${application_version:-latest}"
if [ "$VAULT_REQUESTED_VERSION" = "latest" ]; then
    VAULT_VERSION="$(resolve_latest_vault_version)"
    if [ -z "$VAULT_VERSION" ]; then
        echo "Unable to resolve latest Vault version from HashiCorp Releases API." >&2
        exit 1
    fi
    echo "Resolved latest Vault version: ${VAULT_VERSION}"
else
    VAULT_VERSION="$VAULT_REQUESTED_VERSION"
fi

wget "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
unzip "vault_${VAULT_VERSION}_linux_amd64.zip"
mv vault /usr/bin
mkdir -p /vault/data
groupadd vault
useradd --system --shell /usr/sbin/nologin --home /vault -g vault vault
chown -R vault:vault /vault
swapoff -a

systemctl disable apport.service
echo "root            hard    core            0" >> /etc/security/limits.conf

cat >> /root/.bashrc <<EOM
# generate token and keys
echo "HashiCorp Vault is being initialized"
sleep 5
vault operator init -address=http://127.0.0.1:8200 > /.digitalocean_vault_tokens.txt
cp -f /etc/skel/.bashrc /root/.bashrc
ufw allow 8200
ufw --force enable
echo "HashiCorp Vault is successfully initialized"
EOM

ufw limit ssh
ufw --force enable

build_date=$(date +%Y-%m-%d)
distro="$(lsb_release -s -i)"
distro_release="$(lsb_release -s -r)"
distro_codename="$(lsb_release -s -c)"
distro_arch="$(uname -m)"
install -d -m 0755 /var/lib/digitalocean
cat > /var/lib/digitalocean/application.info <<EOF
application_name="${application_name:-HashiCorp Vault}"
build_date="${build_date}"
distro="${distro}"
distro_release="${distro_release}"
distro_codename="${distro_codename}"
distro_arch="${distro_arch}"
application_version="${VAULT_VERSION}"
EOF
