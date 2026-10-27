#!/bin/bash
# Reinstall nvm Node runtimes (and Bun) with CVE-2026-111497 fixes.
# Upstream codex-universal still ships pre-2026-10-21 Node/Bun builds; Node.js
# patched 22.x / 24.x only (18 / 20 are EOL with no fix).

set -euo pipefail

export NVM_DIR="${NVM_DIR:-/root/.nvm}"
# nvm.sh is not reliable under `set -u` (nounset); toggle around source/use.
set +u
# shellcheck source=/dev/null
. "${NVM_DIR}/nvm.sh"
set -u

NODE_PATCH_VERSIONS=(22.23.4 24.22.1)
NODE_EOL_MAJORS=(18 20)
BUN_PATCH_VERSION=1.4.4

version_ge() {
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]
}

node_version_is_kept() {
    local installed_ver="$1"
    local major="${installed_ver%%.*}"
    local patched patched_major

    for patched in "${NODE_PATCH_VERSIONS[@]}"; do
        patched_major="${patched%%.*}"
        if [ "${major}" = "${patched_major}" ] && version_ge "${installed_ver}" "${patched}"; then
            return 0
        fi
    done
    return 1
}

install_patched_node() {
    local version="$1"
    local major="${version%%.*}"

    echo "Installing patched Node.js ${version}..."
    set +u
    nvm install "${version}"
    nvm use "${version}"
    set -u
    npm install -g npm@11.4 pnpm@10.12
    corepack enable
    corepack install -g yarn
    set +u
    nvm alias "${major}" "${version}"
    set -u
}

for version in "${NODE_PATCH_VERSIONS[@]}"; do
    install_patched_node "${version}"
done

# Stay on a patched runtime while removing older/EOL installs.
set +u
nvm alias default 22
nvm use 22
set -u

for dir in "${NVM_DIR}/versions/node"/v*; do
    [ -d "${dir}" ] || continue
    installed_ver="${dir##*/v}"

    if node_version_is_kept "${installed_ver}"; then
        continue
    fi

    echo "Removing vulnerable/EOL Node.js ${installed_ver}..."
    set +u
    nvm uninstall "${installed_ver}"
    set -u
done

for major in "${NODE_EOL_MAJORS[@]}"; do
    set +u
    nvm unalias "${major}" 2>/dev/null || true
    set -u
done

leftovers=()
for dir in "${NVM_DIR}/versions/node"/v*; do
    [ -d "${dir}" ] || continue
    installed_ver="${dir##*/v}"
    if ! node_version_is_kept "${installed_ver}"; then
        leftovers+=("${installed_ver}")
    fi
done

if [ "${#leftovers[@]}" -gt 0 ]; then
    echo "ERROR: vulnerable/EOL Node.js versions still present after patch: ${leftovers[*]}" >&2
    exit 1
fi

# Positive checks: each patched major must resolve to >= the CVE floor.
for version in "${NODE_PATCH_VERSIONS[@]}"; do
    major="${version%%.*}"
    set +u
    nvm use "${major}" >/dev/null
    set -u
    actual="$(node -v | sed 's/^v//')"
    actual_major="${actual%%.*}"
    if [ "${actual_major}" != "${major}" ]; then
        echo "ERROR: nvm use ${major} selected Node ${actual} (wrong major)" >&2
        exit 1
    fi
    if ! version_ge "${actual}" "${version}"; then
        echo "ERROR: Node.js ${actual} is below CVE-2026-111497 minimum ${version}" >&2
        exit 1
    fi
    echo "  OK: Node ${major} → ${actual} (>= ${version})"
done

set +u
nvm use 22
set -u
nvm cache clear || true
npm cache clean --force || true
pnpm store prune || true
yarn cache clean || true

echo "Upgrading Bun to ${BUN_PATCH_VERSION} (CVE-2026-111497)..."
mise use --global "bun@${BUN_PATCH_VERSION}"

# Drop older Bun installs so the vulnerable binary is not left on disk.
# mise also creates prefix dirs (e.g. "1"); `mise uninstall bun@1` matches
# every 1.x install and fails with "multiple tools specified".
bun_install_root="${HOME}/.local/share/mise/installs/bun"
is_full_semver() {
    case "$1" in
        [0-9]*.[0-9]*.[0-9]*) return 0 ;;
        *) return 1 ;;
    esac
}

if [ -d "${bun_install_root}" ]; then
    for bun_dir in "${bun_install_root}"/*; do
        [ -e "${bun_dir}" ] || continue
        bun_ver="$(basename "${bun_dir}")"

        if is_full_semver "${bun_ver}"; then
            if version_ge "${bun_ver}" "${BUN_PATCH_VERSION}"; then
                continue
            fi
            echo "Removing vulnerable Bun ${bun_ver}..."
            mise uninstall "bun@${bun_ver}"
            continue
        fi

        # Prefix/alias entry (e.g. "1") — remove unless it points at a patched build.
        if [ -L "${bun_dir}" ]; then
            target_ver="$(basename "$(readlink -f "${bun_dir}")")"
            if is_full_semver "${target_ver}" && version_ge "${target_ver}" "${BUN_PATCH_VERSION}"; then
                continue
            fi
        fi
        echo "Removing Bun prefix/alias ${bun_ver}..."
        rm -rf "${bun_dir}"
    done
fi

mise cache clear || true

bun_actual="$(bun --version)"
if ! version_ge "${bun_actual}" "${BUN_PATCH_VERSION}"; then
    echo "ERROR: Bun ${bun_actual} is below CVE-2026-111497 minimum ${BUN_PATCH_VERSION}" >&2
    exit 1
fi

# Ensure no vulnerable full-version Bun installs remain.
if [ -d "${bun_install_root}" ]; then
    bun_leftovers=()
    for bun_dir in "${bun_install_root}"/*; do
        [ -e "${bun_dir}" ] || continue
        bun_ver="$(basename "${bun_dir}")"
        if is_full_semver "${bun_ver}" && ! version_ge "${bun_ver}" "${BUN_PATCH_VERSION}"; then
            bun_leftovers+=("${bun_ver}")
        fi
    done
    if [ "${#bun_leftovers[@]}" -gt 0 ]; then
        echo "ERROR: vulnerable Bun versions still present after patch: ${bun_leftovers[*]}" >&2
        exit 1
    fi
fi

echo "  OK: Bun ${bun_actual} (>= ${BUN_PATCH_VERSION})"
