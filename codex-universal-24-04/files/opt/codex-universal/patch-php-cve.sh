#!/bin/bash
# Rebuild phpenv PHP runtimes with the 2026-11-19 PHP security releases.
# Addresses CVE-2026-115560 (critical RCE) and related CVEs; includes prior
# CVE-2026-109618 / CVE-2026-109619 fixes. php-build definitions for these
# versions ship on the default php-build branch (git pull before install).

set -euo pipefail

PHP_PATCH_VERSIONS=(8.5.13 8.4.28 8.3.37 8.2.36)
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
    mapfile -t _php_candidates < <(ls -d "/root/.phpenv/versions/${major}."* 2>/dev/null | sort -V)
    latest="${_php_candidates[${#_php_candidates[@]}-1]:-}"
    if [ -z "${latest}" ]; then
        echo "ERROR: no patched build found for PHP ${major}.x" >&2
        exit 1
    fi
    rm -rf "/root/.phpenv/versions/${major}snapshot"
    ln -s "${latest}" "/root/.phpenv/versions/${major}snapshot"
done

phpenv rehash

for major in "${PHP_SNAPSHOT_MAJORS[@]}"; do
    echo "PHP ${major} snapshot: $("/root/.phpenv/versions/${major}snapshot/bin/php" -r 'echo PHP_VERSION;')"
done
