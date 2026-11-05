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

# Open-weight models DigitalOcean hosts directly on Serverless Inference
# (owned_by: "digitalocean" in a live GET https://inference.do-ai.run/v1/models
# response, 2026-10-14) — distinct from the proprietary Anthropic/OpenAI-
# branded models also served from the same endpoint, which this droplet does
# not register (BYO-key territory: MODEL_PROVIDER=anthropic/openai above).
# Excludes embeddings/rerankers (bge-*, e5-*, gte-*, qwen3-embedding,
# all-mini-lm-l6-v2), image/audio/video generation (stable-diffusion,
# wan2-2-t2v, qwen3-tts), DO's own router:* pseudo-models, and — per explicit
# request — every nemotron-* model and both openai-gpt-oss-* models (real
# open-weight releases despite the "openai-" id prefix, excluded anyway).
# contextWindow/maxTokens are that response's context_length/max_output_tokens;
# where either was null (kimi-k3, mistral-3-14B's maxTokens), the generic
# fallback (128000/8192 — see DO_GENERIC_CONTEXT_WINDOW/MAX_TOKENS in
# env-lib.sh) is used instead.
OPEN_SOURCE_MODELS = [
    {"id": "deepseek-3.2", "name": "DeepSeek 3.2", "contextWindow": 163840, "maxTokens": 163840},
    {"id": "deepseek-4-flash", "name": "DeepSeek 4 Flash", "contextWindow": 1048576, "maxTokens": 384000},
    {"id": "deepseek-v4-flash-0731", "name": "DeepSeek V4 Flash (0731)", "contextWindow": 1048576, "maxTokens": 1048576},
    {"id": "deepseek-v4-pro", "name": "DeepSeek V4 Pro", "contextWindow": 1048576, "maxTokens": 384000},
    {"id": "deepseek-v4-pro-0813", "name": "DeepSeek V4 Pro (0813)", "contextWindow": 1048576, "maxTokens": 1048576},
    {"id": "deepseek-v4.1-flash", "name": "DeepSeek V4.1 Flash", "contextWindow": 1048576, "maxTokens": 1048576},
    {"id": "gemma-4-31B-it", "name": "Gemma 4 31B IT", "contextWindow": 256000, "maxTokens": 8192},
    {"id": "glm-5.2", "name": "GLM 5.2", "contextWindow": 1048576, "maxTokens": 131072},
    {"id": "glm-5.3", "name": "GLM 5.3", "contextWindow": 1048576, "maxTokens": 128000},
    {"id": "glm-5.3-flash", "name": "GLM 5.3 Flash", "contextWindow": 1048576, "maxTokens": 131072},
    {"id": "kimi-k2.6", "name": "Kimi K2.6", "contextWindow": 262144, "maxTokens": 262144},
    {"id": "kimi-k3", "name": "Kimi K3", "contextWindow": 128000, "maxTokens": 8192},
    {"id": "llama-4-maverick", "name": "Llama 4 Maverick", "contextWindow": 128000, "maxTokens": 16384},
    {"id": "mimo-v2.5-pro", "name": "MiMo V2.5 Pro", "contextWindow": 262144, "maxTokens": 262144},
    {"id": "minimax-m2.5", "name": "MiniMax M2.5", "contextWindow": 65536, "maxTokens": 65536},
    {"id": "mistral-3-14B", "name": "Mistral 3 14B", "contextWindow": 262144, "maxTokens": 8192},
    {"id": "qwen3.5-397b-a17b", "name": "Qwen 3.5 397B A17B", "contextWindow": 131072, "maxTokens": 131072},
    {"id": "qwen3.8-max", "name": "Qwen 3.8 Max", "contextWindow": 1000000, "maxTokens": 262144},
    {"id": "arcee-trinity-large-thinking", "name": "Arcee Trinity Large (Thinking)", "contextWindow": 128000, "maxTokens": 32000},
]


def open_source_models_with_default(model_id: str, model_name: str, context_window: int, max_tokens: int) -> list:
    """The static catalog above, plus the caller's default model (the one
    detect_do_genai_credentials found, or the hardcoded fallback) merged in
    by id — so a default outside the curated catalog (DigitalOcean could
    provision a droplet against any model id) is still registered and
    enabled, and a default that's already in the catalog keeps its catalog
    metadata rather than being overwritten with the generic fallback numbers
    env-lib.sh substitutes for unknown ids."""
    by_id = {m["id"]: dict(m) for m in OPEN_SOURCE_MODELS}
    by_id.setdefault(model_id, {"id": model_id, "name": model_name, "contextWindow": context_window, "maxTokens": max_tokens})
    return list(by_id.values())


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
    model provider (src/api/routes/admin/custom-providers.ts upstream), with
    every model in OPEN_SOURCE_MODELS plus the caller's default (model_id/
    model_name/context_window/max_tokens — see open_source_models_with_default)."""
    do_api_key = os.environ["DO_API_KEY"]
    body = json.dumps(
        {
            "name": "DigitalOcean Serverless Inference",
            "protocol": "openai",
            "baseUrl": "https://inference.do-ai.run/v1",
            "apiKey": do_api_key,
            "models": open_source_models_with_default(model_id, model_name, context_window, max_tokens),
            "validate": True,
        },
        separators=(",", ":"),
    )
    return sign_admin_request(principal, org_id, "PUT", "/v1/admin/custom-providers/digitalocean", body)


def set_webui_models(principal: str, org_id: str, model_id: str, model_name: str,
                      context_window: int, max_tokens: int) -> str:
    """Signed PUT that sets the org's web UI chat-picker allowlist
    (src/api/routes/admin-resources.ts's "webui-models" resource) to every
    model register_do_inference just registered — the same catalog-plus-
    default merge, so the ids line up exactly. Needed in addition to
    register_do_inference: a registered custom provider's models resolve and
    answer turns fine, but the web UI's per-turn model picker is gated by a
    separate durable allowlist (src/core/turn-options.ts's
    validateWebTurnModelOptions, src/api/app-turn.ts's getWebuiModelsDurable)
    that defaults to built-in models only. This also closes a side effect of
    the bystander OPENAI_API_KEY credential (see register_do_inference_provider
    in env-lib.sh): without it, fake-OpenAI-branded built-ins would otherwise
    show up as selectable and fail if chosen.
    """
    model_ids = [m["id"] for m in open_source_models_with_default(model_id, model_name, context_window, max_tokens)]
    body = json.dumps({"ids": model_ids}, separators=(",", ":"))
    scope = f"org%3A{org_id}"
    return sign_admin_request(principal, org_id, "PUT", f"/v1/admin/scopes/{scope}/webui-models", body)


def main() -> None:
    usage = (
        "usage: gen-secrets.py jwk | hash-password | "
        "register-do-inference <principal> <org_id> <model_id> <model_name> <context_window> <max_tokens> | "
        "set-webui-models <principal> <org_id> <model_id> <model_name> <context_window> <max_tokens>"
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
        if len(sys.argv) != 8:
            sys.exit(usage)
        _, _, principal, org_id, model_id, model_name, context_window, max_tokens = sys.argv
        print(set_webui_models(principal, org_id, model_id, model_name, int(context_window), int(max_tokens)))
    else:
        sys.exit(usage)


if __name__ == "__main__":
    main()
