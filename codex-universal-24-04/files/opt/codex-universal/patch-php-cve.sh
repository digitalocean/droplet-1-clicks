#!/bin/bash
# Rebuild phpenv PHP runtimes with CVE-2026-109618 / CVE-2026-109619 fixes.
# Upstream codex-universal still ships May 2026 snapshot builds; php-build
# gained patched definitions on 2026-10-21.

set -euo pipefail

PHP_PATCH_VERSIONS=(8.5.12 8.4.27 8.3.36 8.2.35)
PHP_SNAPSHOT_MAJORS=(8.5 8.4 8.3 8.2)

# Upstream may rename default branch (phpenv: master -> main). Fetch that
# ref and ff-merge FETCH_HEAD so the local branch name does not matter.
git_pull_default() {
    local dir="$1"
    local remote_url branch
    remote_url="$(git -C "${dir}" remote get-url origin)"
    branch="$(
        git ls-remote --symref "${remote_url}" HEAD 2>/dev/null \
            | awk '/^ref:/ { sub("refs/heads/", "", $2); print $2; exit }'
    )"
    if [ -z "${branch}" ]; then
        echo "ERROR: cannot determine default branch of ${remote_url}" >&2
        exit 1
    fi
    git -C "${dir}" fetch --prune -q origin "${branch}"
    git -C "${dir}" merge --ff-only -q FETCH_HEAD
}

git_pull_default /root/.phpenv
git_pull_default /root/.phpenv/plugins/php-build

for version in "${PHP_PATCH_VERSIONS[@]}"; do
    echo "Building patched PHP ${version}..."
    phpenv install -s "${version}"
done

for major in "${PHP_SNAPSHOT_MAJORS[@]}"; do
    latest="$(ls -d "/root/.phpenv/versions/${major}."* 2>/dev/null | sort -V | tail -1)"
    if [ -z "${latest}" ]; then
        echo "ERROR: no patched build found for PHP ${major}.x" >&2
        exit 1
    fi
    rm -rf "/root/.phpenv/versions/${major}snapshot"
    ln -s "${latest}" "/root/.phpenv/versions/${major}snapshot"
done

phpenv rehash

for major in "${PHP_SNAPSHOT_MAJORS[@]}"; do
    "/root/.phpenv/versions/${major}snapshot/bin/php" -v | head -1
done
