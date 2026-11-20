#!/usr/bin/env python3
"""Bake-time checks for Discourse template nginx snippets (CVE-2026-123007)."""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

# Shell snippets in pups exec/cmd steps run under /bin/sh (dash) in the container image.
_PUP_CMD_BASHISM = re.compile(
    r"""
    \becho\s+-e\b |
    \[\[ |
    \$' |
    set\s+-o\s+pipefail |
    \bsource\s+ |
    <<< |
    <\(
    """,
    re.VERBOSE | re.MULTILINE,
)


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


def assert_no_echo_e_in_our_patches(path: Path) -> None:
    if re.search(r"\becho -e\b", path.read_text()):
        raise SystemExit(f"{path}: must not use echo -e (dash prints -e literally)")


def assert_10_http_cmd_posix(web_template: Path) -> None:
    cmd = extract_10_http_write_cmd(web_template.read_text())
    if not cmd:
        raise SystemExit(f"{web_template}: missing pups cmd that writes 10-http.conf")
    if _PUP_CMD_BASHISM.search(cmd):
        raise SystemExit(f"{web_template}: 10-http.conf write cmd must be POSIX sh-safe: {cmd!r}")
    if re.search(r"\becho -e\b", cmd):
        raise SystemExit(f"{web_template}: 10-http.conf write must not use echo -e")
    if not cmd.strip().startswith("printf"):
        raise SystemExit(f"{web_template}: 10-http.conf write must use printf, got: {cmd!r}")


def assert_do_template_hook_cmds_posix(path: Path) -> None:
    """digitalocean-nginx2root.template.yml may embed a bash helper; only hook exec lines use sh."""
    if "digitalocean-nginx2root" not in path.name:
        return
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped.startswith("- "):
            continue
        cmd = stripped[2:].strip()
        if cmd.startswith("/") or cmd.startswith("printf") or cmd.startswith("echo"):
            if _PUP_CMD_BASHISM.search(cmd):
                raise SystemExit(f"{path}: hook exec cmd must be POSIX sh-safe: {cmd!r}")
            if re.search(r"\becho -e\b", cmd):
                raise SystemExit(f"{path}: hook exec must not use echo -e: {cmd!r}")


def extract_10_http_write_cmd(text: str) -> str | None:
    for line in text.splitlines():
        if "10-http.conf" not in line:
            continue
        stripped = line.strip()
        if not (stripped.startswith("-") or stripped.startswith("printf") or stripped.startswith("echo")):
            continue
        cmd = re.sub(r"^\s*-\s+", "", line).strip()
        if "10-http.conf" in cmd and ("printf" in cmd or "echo" in cmd):
            return cmd
    return None


def simulate_10_http_conf_under_sh(web_template: Path) -> None:
    text = web_template.read_text()
    cmd = extract_10_http_write_cmd(text)
    if not cmd:
        raise SystemExit(f"{web_template}: missing pups cmd that writes 10-http.conf")

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        out = root / "10-http.conf"
        cwd = root / "etc" / "nginx" / "conf.d" / "outlets" / "server"
        cwd.mkdir(parents=True)
        rewritten = re.sub(
            r">\s*/etc/nginx/conf\.d/outlets/server/10-http\.conf",
            f"> {cwd / '10-http.conf'}",
            cmd,
        )
        proc = subprocess.run(
            ["sh", "-c", rewritten],
            capture_output=True,
            text=True,
            cwd=tmp,
        )
        if proc.returncode != 0:
            combined = (proc.stdout or "") + (proc.stderr or "")
            raise SystemExit(
                f"sh -c failed simulating 10-http.conf write from {web_template}:\n"
                f"cmd: {rewritten}\n{combined}"
            )
        body = (cwd / "10-http.conf").read_text()
        lines = [ln for ln in body.splitlines() if ln.strip()]
        if not lines:
            raise SystemExit(f"10-http.conf simulation produced empty file from {rewritten}")
        if lines[0].strip() == "-e":
            raise SystemExit(
                f"10-http.conf would start with '-e' under dash (use printf, not echo -e)"
            )
        joined = "\n".join(lines)
        for need in ("listen 80;", "http2 off;"):
            if need not in joined:
                raise SystemExit(f"10-http.conf simulation missing {need!r}: {joined!r}")


def extract_redirect_server_from_web_ssl(path: Path) -> str | None:
    text = path.read_text()
    for block in _server_blocks(text):
        if "return 301 https" in block and "listen 80" in block:
            return block
    return None


def nginx_test_snippets(blocks: list[str], label: str) -> None:
    import shutil

    if not shutil.which("nginx"):
        sys.stderr.write(
            f"discourse-template-nginx2root-checks: nginx missing, skipped nginx -t ({label})\n"
        )
        return

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        includes: list[str] = []
        for i, block in enumerate(blocks):
            snip = root / f"snip-{i}.conf"
            snip.write_text(block + "\n")
            includes.append(f"  include {snip};\n")
        main = root / "nginx.conf"
        main.write_text(
            "events {}\n"
            "http {\n"
            "  http2 off;\n"
            + "".join(includes)
            + "}\n"
        )
        proc = subprocess.run(
            ["nginx", "-t", "-c", str(main)],
            capture_output=True,
            text=True,
        )
        combined = (proc.stdout or "") + (proc.stderr or "")
        if proc.returncode != 0:
            raise SystemExit(f"nginx -t failed ({label}):\n{combined}")


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(f"usage: {sys.argv[0]} <templates...>")

    paths = [Path(p) for p in sys.argv[1:]]
    for path in paths:
        if not path.is_file():
            raise SystemExit(f"missing {path}")
        if path.name.startswith("web."):
            assert_no_echo_e_in_our_patches(path)
        if "digitalocean-nginx2root" in path.name:
            assert_do_template_hook_cmds_posix(path)
        if path.suffix == ".yml" and "web.ssl" in path.name:
            assert_at_most_one_http2_per_server_block(path)

    web_template = next((p for p in paths if p.name == "web.template.yml"), None)
    if web_template:
        assert_10_http_cmd_posix(web_template)
        simulate_10_http_conf_under_sh(web_template)

    web_ssl = next((p for p in paths if p.name == "web.ssl.template.yml"), None)
    nginx_blocks: list[str] = []
    if web_ssl:
        blk = extract_redirect_server_from_web_ssl(web_ssl)
        if blk:
            nginx_blocks.append(blk)
    http_block = (
        "server {\n  listen 80;\n  listen [::]:80;\n  http2 off;\n  return 301 https://example.test;\n}\n"
    )
    nginx_blocks.append(http_block)
    if nginx_blocks:
        nginx_test_snippets(nginx_blocks, "redirect + port-80 outlet")


if __name__ == "__main__":
    main()