#!/usr/bin/env python3
"""Generate the two QM secrets `openssl rand` can't produce on its own:
an EC P-256 private JWK, and a scrypt password hash in QM's own format
(plugins/auth/src/password.ts upstream). Stdlib-only — no Node required.
"""
import base64
import hashlib
import os
import re
import subprocess
import sys


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def gen_jwk() -> str:
    pem = subprocess.run(
        ["openssl", "ecparam", "-genkey", "-name", "prime256v1", "-noout"],
        capture_output=True, text=True, check=True,
    ).stdout
    text = subprocess.run(
        ["openssl", "ec", "-noout", "-text"],
        input=pem, capture_output=True, text=True, check=True,
    ).stdout

    def hex_bytes(section: str) -> bytes:
        return bytes.fromhex(re.sub(r"[^0-9a-f]", "", section))

    priv_section = re.search(r"priv:\s*((?:[0-9a-f:\s]+))pub:", text, re.S)
    pub_section = re.search(r"pub:\s*((?:[0-9a-f:\s]+))ASN1", text, re.S)
    if not priv_section or not pub_section:
        raise RuntimeError(f"could not parse openssl ec -text output:\n{text}")

    priv = hex_bytes(priv_section.group(1)).rjust(32, b"\x00")
    pub = hex_bytes(pub_section.group(1))
    if len(priv) != 32 or len(pub) != 65 or pub[0] != 0x04:
        raise RuntimeError(f"unexpected EC key sizes: priv={len(priv)} pub={len(pub)}")
    x, y = pub[1:33], pub[33:65]

    import json
    return json.dumps({"kty": "EC", "crv": "P-256", "x": b64url(x), "y": b64url(y), "d": b64url(priv)})


def hash_password(password: str) -> str:
    if len(password) < 12:
        raise ValueError("passwords must be at least 12 characters")
    salt = os.urandom(16)
    key = hashlib.scrypt(
        password.encode("utf-8"), salt=salt, n=2 ** 15, r=8, p=1,
        maxmem=256 * 1024 * 1024, dklen=32,
    )
    return "$".join(["scrypt", "15", "8", "1", b64url(salt), b64url(key)])


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in ("jwk", "hash-password"):
        sys.exit("usage: gen-secrets.py jwk | hash-password  (password read from stdin)")
    if sys.argv[1] == "jwk":
        print(gen_jwk())
    else:
        password = sys.stdin.readline().rstrip("\n")
        print(hash_password(password))


if __name__ == "__main__":
    main()
