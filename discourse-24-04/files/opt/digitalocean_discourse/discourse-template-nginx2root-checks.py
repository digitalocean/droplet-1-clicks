#!/usr/bin/env python3
"""Bake-time checks for Discourse template nginx snippets (CVE-2026-123007)."""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path


def _server_blocks(text: str) -> list[str]:
    blocks: list[str] = []
    i = 0
    while True:
        start = text.find("server {", i)
        if start < 0:
            break
        depth = 0
        j = start
        while j < len(text):
            if text.startswith("server {", j):
                depth += 1
                j += len("server {")
                continue
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    blocks.append(text[start : j + 1])
                    i = j + 1
                    break
            j += 1
        else:
            break
    return blocks


def _http2_directive_lines(block: str) -> list[str]:
    out: list[str] = []
    for line in block.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if re.match(r"http2\s+(on|off)\s*;", stripped):
            out.append(line)
    return out


def assert_at_most_one_http2_per_server_block(path: Path) -> None:
    text = path.read_text()
    for idx, block in enumerate(_server_blocks(text)):
        directives = _http2_directive_lines(block)
        if len(directives) > 1:
            raise SystemExit(
                f"{path}: server block #{idx + 1} has {len(directives)} http2 directives "
                f"(expected at most 1)"
            )


def extract_redirect_server_from_web_ssl(path: Path) -> str | None:
    text = path.read_text()
    for block in _server_blocks(text):
        if "return 301 https" in block and "listen 80" in block:
            return block
    return None


def nginx_test_redirect_server_block(block: str) -> None:
    if not block:
        raise SystemExit("redirect server block not found in web.ssl.template.yml")

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        snippet = root / "redirect.conf"
        snippet.write_text(block + "\n")
        main = root / "nginx.conf"
        main.write_text(
            "events {}\n"
            "http {\n"
            "  http2 off;\n"
            f"  include {snippet};\n"
            "}\n"
        )
        proc = subprocess.run(
            ["nginx", "-t", "-c", str(main)],
            capture_output=True,
            text=True,
        )
        combined = (proc.stdout or "") + (proc.stderr or "")
        if proc.returncode != 0:
            raise SystemExit(f"nginx -t failed on rendered redirect server block:\n{combined}")


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(f"usage: {sys.argv[0]} <web.ssl.template.yml> [more.yml ...]")

    paths = [Path(p) for p in sys.argv[1:]]
    for path in paths:
        if not path.is_file():
            raise SystemExit(f"missing {path}")
        assert_at_most_one_http2_per_server_block(path)

    web_ssl = paths[0]
    if web_ssl.name == "web.ssl.template.yml":
        block = extract_redirect_server_from_web_ssl(web_ssl)
        if block:
            if shutil_which("nginx"):
                nginx_test_redirect_server_block(block)
            else:
                sys.stderr.write(
                    "discourse-template-nginx2root-checks: nginx binary missing, "
                    "skipped nginx -t on redirect block\n"
                )


def shutil_which(cmd: str) -> bool:
    import shutil

    return shutil.which(cmd) is not None


if __name__ == "__main__":
    main()