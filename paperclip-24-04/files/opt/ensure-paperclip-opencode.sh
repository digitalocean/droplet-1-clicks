#!/bin/bash
# Install the OpenCode CLI on the Paperclip host.
#
# Hiring an OpenCode agent runs a local hello probe (`opencode run`) before
# the agent can leave "verifying". Paperclip only auto-installs that CLI
# inside a sandbox, so a missing host binary fails the probe and Retry
# reports "The lifecycle step failed. Retry the operation."
# Image bake fails when this cannot install. First boot and update warn and
# continue, so a later download failure does not stop Paperclip.
# The paperclip service PATH includes /usr/local/bin. Copy the binary there;
# a symlink into /root is not executable by the paperclip user.
set -euo pipefail

BIN=/usr/local/bin/opencode

if [ -x "$BIN" ]; then
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: $0" >&2
  exit 1
fi

export HOME=/root
curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path

src=""
for candidate in /root/.opencode/bin/opencode /home/paperclip/.opencode/bin/opencode; do
  if [ -x "$candidate" ]; then
    src="$candidate"
    break
  fi
done

if [ -z "$src" ]; then
  echo "ERROR: OpenCode installer did not produce a binary" >&2
  exit 1
fi

install -m 755 "$src" "$BIN"
"$BIN" --version
