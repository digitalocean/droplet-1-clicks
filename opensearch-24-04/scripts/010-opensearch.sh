#!/bin/sh
set -eu

# Official OpenSearch + Dashboards APT repos (see OpenSearch Debian install docs)
install -d -m 0755 /etc/apt/keyrings

curl -fsSL https://artifacts.opensearch.org/publickeys/opensearch-release.pgp \
  | gpg --dearmor --batch --yes -o /etc/apt/keyrings/opensearch.gpg
chmod a+r /etc/apt/keyrings/opensearch.gpg

curl -fsSL https://artifacts.opensearch.org/publickeys/opensearch-release.pgp \
  | gpg --dearmor --batch --yes -o /etc/apt/keyrings/opensearch-release-keyring
chmod a+r /etc/apt/keyrings/opensearch-release-keyring

echo "deb [signed-by=/etc/apt/keyrings/opensearch.gpg] https://artifacts.opensearch.org/releases/bundle/opensearch/${repo_version}/apt stable main" \
  > /etc/apt/sources.list.d/opensearch-${repo_version}.list

echo "deb [signed-by=/etc/apt/keyrings/opensearch-release-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/${repo_version}/apt stable main" \
  > /etc/apt/sources.list.d/opensearch-dashboards-${repo_version}.list

apt-get update
apt-get update --allow-releaseinfo-change || true

# Ensure first-boot script and MOTD are executable for cloud-init / login
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click
