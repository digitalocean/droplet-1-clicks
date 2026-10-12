#!/usr/bin/env python3
"""Generate the QM secrets/requests `openssl`/`curl` can't produce on their
own: an EC P-256 private JWK, a scrypt password hash in QM's own format
(plugins/auth/src/password.ts upstream), and signed internal admin requests
(src/auth/source-auth-sign.ts + src/auth/signed-token.ts upstream) used at
first boot to auto-register a custom model provider and enable it for the
web UI's chat picker. Stdlib-only — no Node required.
"""
import base64
import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
import time


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


# --- Internal signed-admin-request helpers ---------------------------------
# Reproduces src/auth/source-auth-sign.ts (request signing) and
# src/auth/signed-token.ts's mintSignedPayload (portal-identity JWS) exactly:
# both are plain HMAC-SHA256 underneath (the JWS is HS256 compact
# serialization per RFC 7515 — unambiguous, no library-specific behavior to
# diverge from), so no Node/jose dependency is needed to produce a token
# `verifySignedPayload`/`authorizeAdmin` on the real core accepts.


def signing_key_id(secret: str) -> str:
    digest = hmac.new(secret.encode(), b"qm-signing-key-id", hashlib.sha256).digest()
    return b64url(digest)[:8]


def jws_compact(secret: str, payload_obj: dict) -> str:
    header = {"alg": "HS256", "kid": signing_key_id(secret)}
    header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode())
    payload_b64 = b64url(json.dumps(payload_obj, separators=(",", ":")).encode())
    signing_input = f"{header_b64}.{payload_b64}".encode()
    sig = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    return f"{header_b64}.{payload_b64}.{b64url(sig)}"


def canonical_payload(method: str, path_with_query: str, body: str) -> str:
    return f"{method}\n{path_with_query}\n{body}"


def sign_request(secret: str, timestamp_sec: int, canonical: str) -> str:
    mac = hmac.new(secret.encode(), f"v0:{timestamp_sec}:{canonical}".encode(), hashlib.sha256).hexdigest()
    return f"v0={mac}"


def sign_admin_request(principal: str, org_id: str, method: str, path: str, body: str) -> str:
    """Builds a signed admin request core's internal auth
    (src/api/routes/shared.ts's authorizeAdmin) will accept. Prints one JSON
    object: {method, path, body, headers} — body is the exact string that was
    signed, so the caller must send that literal string, not re-serialize it.
    """
    core_secret = os.environ["CORE_SIGNING_SECRET"]
    portal_secret = os.environ["PORTAL_IDENTITY_SECRET"]

    now_ms = int(time.time() * 1000)
    now_sec = now_ms // 1000
    portal_identity = jws_compact(portal_secret, {"p": principal, "exp": now_ms + 60_000})
    signature = sign_request(core_secret, now_sec, canonical_payload(method, path, body))

    return json.dumps(
        {
            "method": method,
            "path": path,
            "body": body,
            "headers": {
                "x-admin-actor": f"{principal}@{org_id}",
                "x-portal-identity": portal_identity,
                "x-timestamp": str(now_sec),
                "x-signature": signature,
            },
        }
    )


def register_do_inference(principal: str, org_id: str, model_id: str, model_name: str,
                           context_window: int, max_tokens: int) -> str:
    """Signed PUT that registers DigitalOcean Serverless Inference as a custom
    model provider (src/api/routes/admin/custom-providers.ts upstream)."""
    do_api_key = os.environ["DO_API_KEY"]
    body = json.dumps(
        {
            "name": "DigitalOcean Serverless Inference",
            "protocol": "openai",
            "baseUrl": "https://inference.do-ai.run/v1",
            "apiKey": do_api_key,
            "models": [
                {"id": model_id, "name": model_name, "contextWindow": context_window, "maxTokens": max_tokens},
            ],
            "validate": True,
        },
        separators=(",", ":"),
    )
    return sign_admin_request(principal, org_id, "PUT", "/v1/admin/custom-providers/digitalocean", body)


def set_webui_models(principal: str, org_id: str, model_id: str) -> str:
    """Signed PUT that sets the org's web UI chat-picker allowlist
    (src/api/routes/admin-resources.ts's "webui-models" resource) to just the
    given model id. Needed in addition to register_do_inference: a registered
    custom provider's model resolves and answers turns fine, but the web UI's
    per-turn model picker is gated by a separate durable allowlist
    (src/core/turn-options.ts's validateWebTurnModelOptions,
    src/api/app-turn.ts's getWebuiModelsDurable) that defaults to built-in
    models only. This also closes a side effect of the bystander
    OPENAI_API_KEY credential (see register_do_inference_provider in
    env-lib.sh): without it, fake-OpenAI-branded built-ins would otherwise
    show up as selectable and fail if chosen.
    """
    body = json.dumps({"ids": [model_id]}, separators=(",", ":"))
    scope = f"org%3A{org_id}"
    return sign_admin_request(principal, org_id, "PUT", f"/v1/admin/scopes/{scope}/webui-models", body)


def main() -> None:
    usage = (
        "usage: gen-secrets.py jwk | hash-password | "
        "register-do-inference <principal> <org_id> <model_id> <model_name> <context_window> <max_tokens> | "
        "set-webui-models <principal> <org_id> <model_id>"
    )
    if len(sys.argv) < 2:
        sys.exit(usage)
    cmd = sys.argv[1]
    if cmd == "jwk":
        print(gen_jwk())
    elif cmd == "hash-password":
        password = sys.stdin.readline().rstrip("\n")
        print(hash_password(password))
    elif cmd == "register-do-inference":
        if len(sys.argv) != 8:
            sys.exit(usage)
        _, _, principal, org_id, model_id, model_name, context_window, max_tokens = sys.argv
        print(register_do_inference(principal, org_id, model_id, model_name, int(context_window), int(max_tokens)))
    elif cmd == "set-webui-models":
        if len(sys.argv) != 5:
            sys.exit(usage)
        _, _, principal, org_id, model_id = sys.argv
        print(set_webui_models(principal, org_id, model_id))
    else:
        sys.exit(usage)


if __name__ == "__main__":
    main()
