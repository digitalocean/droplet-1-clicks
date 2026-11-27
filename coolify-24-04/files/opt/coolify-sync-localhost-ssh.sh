#!/bin/bash
#
# Sync Coolify localhost SSH trust after Coolify rewrites key files.
#
# Coolify's PopulateSshKeysDirectorySeeder deletes /data/coolify/ssh/keys and
# rewrites private keys as ssh_key@<uuid>. That removes id.root@host.docker.internal
# (UI onboarding "point 3" path). This script:
#   1) Resolves Coolify's real localhost private key (DB id 0 / ssh_key@uuid)
#   2) Restores id.root@host.docker.internal from that same key material
#   3) Authorizes the matching pubkey in /etc/ssh/authorized_keys.d/coolify
#      (follow-up to #509: keep Validate trust; img_check only looks at
#      ~/.ssh/authorized_keys, so Coolify trust must stay elsewhere; sshd
#      Match User root also reads this file for root)
#   4) Forces Coolify localhost server SSH port to 22 when DB is reachable
#
# Never generates a new keypair Coolify does not already know — that would break
# onboarding Validate (UI "Current Public Key" would not match host trust).

set -euo pipefail

SSH_KEYS_DIR="/data/coolify/ssh/keys"
LEGACY_KEY_PATH="${SSH_KEYS_DIR}/id.root@host.docker.internal"
ENV_FILE="/data/coolify/source/.env"
# Coolify-managed trust only — see sshd_config.d/99-coolify-authorized-keys.conf
AUTH_KEYS="/etc/ssh/authorized_keys.d/coolify"
ROOT_AUTH_KEYS="/root/.ssh/authorized_keys"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${SSH_KEYS_DIR}" /root/.ssh /etc/ssh/authorized_keys.d
chmod 700 /root/.ssh "${SSH_KEYS_DIR}"
chmod 755 /etc/ssh/authorized_keys.d
touch "${AUTH_KEYS}"
chmod 600 "${AUTH_KEYS}"

coolify_container() {
    docker ps --format '{{.Names}}' | grep -E '^coolify$' | head -1 || true
}

# Drop Coolify-managed trust lines (legacy coolify comment + Coolify cpk: lines).
strip_coolify_lines_from_file() {
    local keys_file="$1"
    if [ ! -f "${keys_file}" ]; then
        return 0
    fi
    sed -i -E \
        -e '/[[:space:]](root@)?coolify[[:space:]]*$/d' \
        -e '/[[:space:]]cpk:[^[:space:]]+/d' \
        "${keys_file}" 2>/dev/null || true
    chmod 600 "${keys_file}"
}

# Clear Coolify trust in the Coolify keys file, and scrub any leftover Coolify
# lines from ~/.ssh/authorized_keys (pre-fix images / manual pastes) so
# marketplace img_check and DO/user keys stay clean.
strip_coolify_authorized_keys() {
    strip_coolify_lines_from_file "${AUTH_KEYS}"
    strip_coolify_lines_from_file "${ROOT_AUTH_KEYS}"
}

authorize_pubkey_line() {
    local body comment line
    body="$1"
    comment="${2:-coolify}"
    [ -n "${body}" ] || return 0

    if grep -qF "${body}" "${AUTH_KEYS}" 2>/dev/null; then
        grep -vF "${body}" "${AUTH_KEYS}" > "${AUTH_KEYS}.tmp" || true
        cat "${AUTH_KEYS}.tmp" > "${AUTH_KEYS}"
        rm -f "${AUTH_KEYS}.tmp"
    fi

    line="${body} ${comment}"
    echo "${line}" >> "${AUTH_KEYS}"
    chmod 600 "${AUTH_KEYS}"
}

authorize_private_key_file() {
    local key_file="$1"
    local pub body

    [ -f "${key_file}" ] || return 1
    case "${key_file}" in
        *.pub|*.lock|*.dbtmp) return 1 ;;
    esac

    # Reject unreadable / non-OpenSSH material before trusting it
    pub=$(ssh-keygen -y -f "${key_file}" 2>/dev/null) || return 1
    body=$(echo "${pub}" | awk '{print $1" "$2}')
    [ -n "${body}" ] || return 1

    authorize_pubkey_line "${body}" "coolify"
    return 0
}

install_validated_private_key() {
    local src="$1"
    local dest="$2"

    [ -f "${src}" ] || return 1
    if ! ssh-keygen -y -f "${src}" >/dev/null 2>&1; then
        echo "Rejecting invalid private key candidate: ${src}"
        return 1
    fi

    safe_copy_key "${src}" "${dest}"
    ssh-keygen -y -f "${dest}" > "${dest}.pub"
    chown 9999:root "${dest}" "${dest}.pub"
    chmod 600 "${dest}"
    chmod 644 "${dest}.pub"
    authorize_private_key_file "${dest}"
}

# Decrypt localhost private key via Coolify app (DB value is encrypted).
# Writes validated key to TMP_DIR/localhost.key and uuid to TMP_DIR/localhost.uuid
export_localhost_key_from_app() {
    local cid key_tmp uuid_tmp pub_tmp
    cid=$(coolify_container)
    [ -n "${cid}" ] || return 1

    key_tmp="${TMP_DIR}/localhost.key"
    uuid_tmp="${TMP_DIR}/localhost.uuid"
    pub_tmp="${TMP_DIR}/localhost.pub"
    rm -f "${key_tmp}" "${uuid_tmp}" "${pub_tmp}"

    # Write files inside the container to avoid tinker stdout noise
    if ! docker exec "${cid}" php artisan tinker --execute='
$k = App\Models\PrivateKey::find(0)
    ?: App\Models\PrivateKey::query()->where("name", "like", "%localhost%")->orderBy("id")->first()
    ?: App\Models\PrivateKey::query()->where("is_git_related", false)->orderBy("id")->first();
if (!$k || !$k->private_key) { exit(1); }
file_put_contents("/tmp/coolify-localhost.key", $k->private_key);
file_put_contents("/tmp/coolify-localhost.uuid", (string) $k->uuid);
file_put_contents("/tmp/coolify-localhost.pub", (string) ($k->public_key ?? ""));
' >/dev/null 2>&1; then
        return 1
    fi

    docker cp "${cid}:/tmp/coolify-localhost.key" "${key_tmp}" >/dev/null 2>&1 || return 1
    docker cp "${cid}:/tmp/coolify-localhost.uuid" "${uuid_tmp}" >/dev/null 2>&1 || true
    docker cp "${cid}:/tmp/coolify-localhost.pub" "${pub_tmp}" >/dev/null 2>&1 || true
    docker exec "${cid}" rm -f /tmp/coolify-localhost.key /tmp/coolify-localhost.uuid /tmp/coolify-localhost.pub >/dev/null 2>&1 || true

    if ! ssh-keygen -y -f "${key_tmp}" >/dev/null 2>&1; then
        echo "Exported Coolify DB key failed ssh-keygen validation (will use on-disk key if present)"
        # Keep uuid/pub for disk resolution; drop invalid private key material
        rm -f "${key_tmp}"
        return 1
    fi

    return 0
}

# Copy only when source and destination differ (avoids "are the same file" under set -e)
safe_copy_key() {
    local src="$1"
    local dest="$2"

    [ -f "${src}" ] || return 1
    if [ "${src}" -ef "${dest}" ] 2>/dev/null || [ "${src}" = "${dest}" ]; then
        return 0
    fi
    cp -f "${src}" "${dest}"
}

key_matches_app_pubkey() {
    local key_file="$1"
    local want pub_body

    [ -f "${key_file}" ] || return 1
    if [ ! -f "${TMP_DIR}/localhost.pub" ]; then
        # No app pubkey to compare — accept if the key parses
        ssh-keygen -y -f "${key_file}" >/dev/null 2>&1
        return $?
    fi

    want=$(awk '{print $1" "$2}' "${TMP_DIR}/localhost.pub")
    [ -n "${want}" ] || return 1
    pub_body=$(ssh-keygen -y -f "${key_file}" 2>/dev/null | awk '{print $1" "$2}')
    [ -n "${pub_body}" ] || return 1
    [ "${pub_body}" = "${want}" ]
}

resolve_localhost_key_on_disk() {
    local uuid=""
    local candidate=""

    # Prefer Coolify runtime path by uuid (authoritative after reseed)
    if [ -f "${TMP_DIR}/localhost.uuid" ]; then
        uuid=$(tr -d '[:space:]' < "${TMP_DIR}/localhost.uuid" || true)
        if [ -n "${uuid}" ] && key_matches_app_pubkey "${SSH_KEYS_DIR}/ssh_key@${uuid}"; then
            echo "${SSH_KEYS_DIR}/ssh_key@${uuid}"
            return 0
        fi
    fi

    # Legacy path only if it matches Coolify's current pubkey (avoid stale pre-reseed key)
    if key_matches_app_pubkey "${LEGACY_KEY_PATH}"; then
        echo "${LEGACY_KEY_PATH}"
        return 0
    fi

    # Match any ssh_key@* to Coolify-exported pubkey
    if [ -f "${TMP_DIR}/localhost.pub" ]; then
        local want
        want=$(awk '{print $1" "$2}' "${TMP_DIR}/localhost.pub")
        if [ -n "${want}" ]; then
            shopt -s nullglob
            for candidate in "${SSH_KEYS_DIR}"/ssh_key@*; do
                if key_matches_app_pubkey "${candidate}"; then
                    shopt -u nullglob
                    echo "${candidate}"
                    return 0
                fi
            done
            shopt -u nullglob
        fi
    fi

    # Fresh install fallback: exactly one ssh_key@* and no app pubkey available yet
    if [ ! -f "${TMP_DIR}/localhost.pub" ]; then
        shopt -s nullglob
        local keys=("${SSH_KEYS_DIR}"/ssh_key@*)
        shopt -u nullglob
        if [ "${#keys[@]}" -eq 1 ] && ssh-keygen -y -f "${keys[0]}" >/dev/null 2>&1; then
            echo "${keys[0]}"
            return 0
        fi
        if [ -f "${LEGACY_KEY_PATH}" ] && ssh-keygen -y -f "${LEGACY_KEY_PATH}" >/dev/null 2>&1; then
            echo "${LEGACY_KEY_PATH}"
            return 0
        fi
    fi

    return 1
}

authorize_coolify_pubkey_only() {
    # Last-resort: trust Coolify's public_key without writing a new private key
    local body
    [ -f "${TMP_DIR}/localhost.pub" ] || return 1
    body=$(awk '{print $1" "$2}' "${TMP_DIR}/localhost.pub")
    [ -n "${body}" ] || return 1
    authorize_pubkey_line "${body}" "coolify"
    echo "Authorized Coolify public key from app (private key file still missing on disk)"
    return 0
}

reset_localhost_ssh_port() {
    local db_password db_username db_database db_container

    [ -f "${ENV_FILE}" ] || return 1

    db_password=$(grep -E '^DB_PASSWORD=' "${ENV_FILE}" | head -1 | cut -d= -f2-)
    db_username=$(grep -E '^DB_USERNAME=' "${ENV_FILE}" | head -1 | cut -d= -f2-)
    db_database=$(grep -E '^DB_DATABASE=' "${ENV_FILE}" | head -1 | cut -d= -f2-)
    db_username=${db_username:-coolify}
    db_database=${db_database:-coolify}

    db_container=$(docker ps --format '{{.Names}}' | grep -E '^coolify-db$' | head -1 || true)
    if [ -z "${db_container}" ] || [ -z "${db_password}" ]; then
        return 1
    fi

    if docker exec -e PGPASSWORD="${db_password}" "${db_container}" \
        psql -U "${db_username}" -d "${db_database}" -v ON_ERROR_STOP=1 \
        -c "UPDATE servers SET port = 22 WHERE ip IN ('host.docker.internal', 'localhost') AND CAST(port AS integer) <> 22;" \
        >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

echo "Syncing Coolify localhost SSH trust..."

# Clear prior Coolify trust lines before adding only the localhost key
strip_coolify_authorized_keys

# Prefer Coolify's own localhost key (DB) so UI "Current Public Key" matches host trust
HAVE_APP_KEY=0
if export_localhost_key_from_app; then
    HAVE_APP_KEY=1
    echo "Loaded localhost private key from Coolify application"
fi

SOURCE_KEY=""
if SOURCE_KEY=$(resolve_localhost_key_on_disk); then
    echo "Using on-disk localhost key: ${SOURCE_KEY}"
elif [ "${HAVE_APP_KEY}" -eq 1 ]; then
    SOURCE_KEY="${TMP_DIR}/localhost.key"
    echo "Using private key exported from Coolify DB"
else
    SOURCE_KEY=""
fi

# Authorize ONLY the localhost key (not every ssh_key@* on disk)
if [ -n "${SOURCE_KEY}" ] && [ -f "${SOURCE_KEY}" ]; then
    install_validated_private_key "${SOURCE_KEY}" "${LEGACY_KEY_PATH}"
    # Also ensure ssh_key@uuid exists when we know the uuid (Coolify runtime path)
    if [ -f "${TMP_DIR}/localhost.uuid" ]; then
        uuid=$(tr -d '[:space:]' < "${TMP_DIR}/localhost.uuid" || true)
        if [ -n "${uuid}" ]; then
            runtime_key="${SSH_KEYS_DIR}/ssh_key@${uuid}"
            # Skip when SOURCE_KEY is already that runtime file
            if [ "${SOURCE_KEY}" != "${runtime_key}" ] && ! [ "${SOURCE_KEY}" -ef "${runtime_key}" ] 2>/dev/null; then
                if ssh-keygen -y -f "${SOURCE_KEY}" >/dev/null 2>&1; then
                    safe_copy_key "${SOURCE_KEY}" "${runtime_key}"
                    chown 9999:root "${runtime_key}"
                    chmod 600 "${runtime_key}"
                fi
            fi
        fi
    fi
else
    echo "WARNING: Could not locate Coolify localhost private key on disk or in DB."
    if ! authorize_coolify_pubkey_only; then
        echo "WARNING: Unable to authorize Coolify localhost key."
        echo "  Run again after Coolify is healthy, or paste the UI Current Public Key into ${AUTH_KEYS}"
        echo "  (not ${ROOT_AUTH_KEYS} — marketplace img_check requires that file stay Coolify-free)"
        echo "  then: /opt/configure-coolify-localhost.sh"
    fi
fi

chown -R 9999:root /data/coolify/ssh
chmod -R 700 /data/coolify/ssh
find "${SSH_KEYS_DIR}" -maxdepth 1 -type f ! -name '*.pub' ! -name '*.lock' -exec chmod 600 {} \; 2>/dev/null || true
find "${SSH_KEYS_DIR}" -maxdepth 1 -type f -name '*.pub' -exec chmod 644 {} \; 2>/dev/null || true

if reset_localhost_ssh_port; then
    echo "Localhost SSH port set to 22 in Coolify database"
else
    echo "Could not update Coolify DB port (UI: Servers → localhost → SSH port 22)"
fi

# Host-side smoke test (UI onboarding point 3) — only real SSH success counts as SYNC_OK
SYNC_OK=0
if [ -f "${LEGACY_KEY_PATH}" ] && ssh -i "${LEGACY_KEY_PATH}" -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@127.0.0.1 true 2>/dev/null; then
    echo "Host SSH check OK: ssh -i ${LEGACY_KEY_PATH} root@127.0.0.1"
    SYNC_OK=1
else
    echo "WARNING: Host SSH check failed for ${LEGACY_KEY_PATH:-missing}"
    echo "  Repair: /opt/configure-coolify-localhost.sh"
fi

echo "Coolify localhost SSH sync complete."
if [ "${SYNC_OK}" -eq 1 ]; then
    exit 0
fi
exit 1
