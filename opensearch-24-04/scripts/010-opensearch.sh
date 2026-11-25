#!/bin/sh

# Package install happens on first boot (001_onboot). That script enforces the
# CVE-2026-114938 (Java4Shell) floor for opensearch (>= 3.10.1, bundled JDK
# 25.0.5.1+2), installs Dashboards separately (3.10.1 not yet in apt; Node.js
# and not Java4Shell-affected), applies -XX:-UseBASE64Intrinsics, and unlocks
# SSH via EXIT trap.

# Add OpenSearch and OpenSearch Dashboard GPG keys
curl -fsSL https://artifacts.opensearch.org/publickeys/opensearch-release.pgp \
 | sudo gpg --dearmor -o /etc/apt/keyrings/opensearch.gpg

curl -o- https://artifacts.opensearch.org/publickeys/opensearch-release.pgp | sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/opensearch-release-keyring

# Add OpenSearch repository
echo "deb [signed-by=/etc/apt/keyrings/opensearch.gpg] https://artifacts.opensearch.org/releases/bundle/opensearch/${repo_version}/apt stable main" \
| sudo tee /etc/apt/sources.list.d/opensearch-${repo_version}.list
echo "deb [signed-by=/etc/apt/keyrings/opensearch-release-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/${repo_version}/apt stable main" | sudo tee /etc/apt/sources.list.d/opensearch-dashboards-${repo_version}.list

sudo apt-get update
