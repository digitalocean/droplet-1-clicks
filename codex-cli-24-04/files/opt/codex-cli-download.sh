#!/bin/bash
# Shared download + SHA256 verification for Codex CLI GitHub release assets.
set -euo pipefail

ARCH="${CODEX_ARCH:-x86_64-unknown-linux-musl}"
CODEX_LIB_DIR="${CODEX_LIB_DIR:-/usr/local/lib/codex}"

verify_sha256() {
    local file="$1" expected="$2"
    local actual
    actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" != "$expected" ]; then
        echo "Error: SHA256 mismatch for $(basename "$file")" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        return 1
    fi
}

fetch_release_asset_digest() {
    local tag="$1" asset_name="$2"
    # GitHub only computes asset digests for uploads since June 2025.
    # Older release assets return digest: null — treat that as "unavailable".
    curl -fsSL "https://api.github.com/repos/openai/codex/releases/tags/${tag}" \
        | jq -r --arg name "$asset_name" '
            .assets[]
            | select(.name == $name)
            | .digest
            | select(. != null and . != "")
            | sub("^sha256:"; "")
          '
}

download_codex_release_asset() {
    local tag="$1" asset_name="$2" dest="$3"
    local expected_sha256=""

    local url="https://github.com/openai/codex/releases/download/${tag}/${asset_name}"
    curl -fsSL "$url" -o "$dest"

    # Always resolve SHA256 from the release tag being installed so a version
    # bump cannot reuse a stale checksum from an older pin.
    expected_sha256=$(fetch_release_asset_digest "$tag" "$asset_name" || true)

    if [ -z "$expected_sha256" ] || [ "$expected_sha256" = "null" ]; then
        echo "Error: Could not determine SHA256 for ${asset_name} (tag ${tag})." >&2
        echo "GitHub asset digests are unavailable for some older uploads." >&2
        return 1
    fi

    verify_sha256 "$dest" "$expected_sha256"
}

install_codex_binaries() {
    local tag="$1" tmpdir="$2"
    local codex_asset="codex-${ARCH}.tar.gz"
    local bwrap_asset="bwrap-${ARCH}.tar.gz"

    mkdir -p "$CODEX_LIB_DIR"

    echo "Downloading ${codex_asset}..."
    download_codex_release_asset "$tag" "$codex_asset" "${tmpdir}/codex.tar.gz"
    tar -xzf "${tmpdir}/codex.tar.gz" -C "${tmpdir}"
    install -m 0755 "${tmpdir}/codex-${ARCH}" "${CODEX_LIB_DIR}/codex"

    echo "Downloading ${bwrap_asset}..."
    download_codex_release_asset "$tag" "$bwrap_asset" "${tmpdir}/bwrap.tar.gz"
    tar -xzf "${tmpdir}/bwrap.tar.gz" -C "${tmpdir}"
    install -m 0755 "${tmpdir}/bwrap-${ARCH}" /usr/local/bin/bwrap
}