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

# codex and bwrap come from the same tag, so one release document covers both.
fetch_release_json() {
    local tag="$1" dest="$2"
    if ! curl -fsSL \
        "https://api.github.com/repos/openai/codex/releases/tags/${tag}" \
        -o "$dest"; then
        echo "Error: GitHub API request failed for tag ${tag}." >&2
        return 1
    fi
    # curl -f misses a 200 body that is not a release (rate-limit JSON, HTML).
    if ! jq -e '.assets | type == "array"' "$dest" >/dev/null 2>&1; then
        echo "Error: GitHub API request failed for tag ${tag}." >&2
        return 1
    fi
}

# Hex digest on stdout. Empty stdout means this release has no digest for the
# asset. Non-zero means the saved body could not be read.
release_asset_digest() {
    local release_json="$1" asset_name="$2"
    jq -r --arg name "$asset_name" '
        .assets[]
        | select(.name == $name)
        | .digest
        | select(. != null and . != "")
        | sub("^sha256:"; "")
    ' "$release_json" 2>/dev/null
}

download_codex_release_asset() {
    local tag="$1" asset_name="$2" dest="$3" release_json="$4"
    local expected_sha256=""
    local url="https://github.com/openai/codex/releases/download/${tag}/${asset_name}"

    if ! expected_sha256=$(release_asset_digest "$release_json" "$asset_name"); then
        echo "Error: GitHub API request failed for tag ${tag}." >&2
        return 1
    fi

    # GitHub only computes asset digests for uploads since June 2025.
    if [ -z "$expected_sha256" ]; then
        echo "Error: Could not determine SHA256 for ${asset_name} (tag ${tag})." >&2
        echo "GitHub asset digests are unavailable for some older uploads." >&2
        return 1
    fi

    curl -fsSL "$url" -o "$dest"
    # Expected SHA256 is the GitHub digest for this version's release tag.
    verify_sha256 "$dest" "$expected_sha256"
}

install_codex_binaries() {
    local tag="$1" tmpdir="$2"
    local codex_asset="codex-${ARCH}.tar.gz"
    local bwrap_asset="bwrap-${ARCH}.tar.gz"
    local release_json="${tmpdir}/release.json"

    mkdir -p "$CODEX_LIB_DIR"
    # One release document covers both assets for this tag.
    fetch_release_json "$tag" "$release_json"

    echo "Downloading ${codex_asset}..."
    download_codex_release_asset "$tag" "$codex_asset" "${tmpdir}/codex.tar.gz" "$release_json"
    tar -xzf "${tmpdir}/codex.tar.gz" -C "${tmpdir}"
    install -m 0755 "${tmpdir}/codex-${ARCH}" "${CODEX_LIB_DIR}/codex"

    echo "Downloading ${bwrap_asset}..."
    download_codex_release_asset "$tag" "$bwrap_asset" "${tmpdir}/bwrap.tar.gz" "$release_json"
    tar -xzf "${tmpdir}/bwrap.tar.gz" -C "${tmpdir}"
    install -m 0755 "${tmpdir}/bwrap-${ARCH}" /usr/local/bin/bwrap
}
