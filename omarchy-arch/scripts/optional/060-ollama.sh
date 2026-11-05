#!/bin/bash
#
# OPTIONAL: Ollama with models baked into the image, for GPU droplets.
#
# Gated on the same gpu_available build variable as 050-nvidia.sh, and must run
# AFTER it, which pulls in the CUDA stack ollama-cuda needs.
#
# The model set comes from the ollama_models build variable, so a build can
# ship a different selection without editing this file. Set it to an empty
# string to install Ollama and its service but download nothing, which keeps
# the image small and leaves users to `ollama pull` what they want.
#
# SIZE WARNING: models dominate the image. The default set is roughly 240 GB on
# disk, against ~7 GB for the standard Omarchy image, and the snapshot's minimum
# disk size grows to match. Note that Ollama pulls at about 1 GB/s on a GPU
# droplet, so baking the set in saves a user around four minutes, not hours: it
# buys a droplet that is useful at first boot and needs no egress later, at the
# cost of a very large image. Trim the list if that trade is wrong for you.
set -euo pipefail

if [[ ${gpu_available:-false} != "true" ]]; then
  echo "==> Skipping Ollama (gpu_available=${gpu_available:-false})"
  exit 0
fi

# Benchmarked on an H100 80GB (generation throughput, all fully GPU-resident
# except the 125B, which spills to system RAM and is still the strongest
# reasoner). Kept in fastest-first order so the first entry is the default a
# user meets.
DEFAULT_MODELS="qwen3.8:27b-mtp-q8_0 qwen3.8-flash-next:125b-a6b-q4_K_M gemma4:31b-it-q8_0 qwen3.8:27b-bf16"
MODELS="${ollama_models-$DEFAULT_MODELS}"

echo "==> Installing Ollama with CUDA support"
# ollama-cuda depends on both ollama and cuda, so this one package brings the
# server, the CUDA runtime and the GPU-enabled backend. Without it Ollama runs,
# but silently on the CPU, which on these models is the difference between
# ~100 tokens/s and unusable.
sudo pacman -S --noconfirm --needed ollama-cuda 2>&1 | tail -1
ollama --version 2>/dev/null | head -1 || true

echo "==> Configuring the ollama service"
# The Arch package already ships a unit that runs `ollama serve` as the ollama
# user with OLLAMA_MODELS=/var/lib/ollama, so this only overrides what we
# actually want to differ from the packaged defaults.
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/omarchy.conf >/dev/null <<'EOF'
[Service]
# Bind to loopback explicitly rather than inheriting a default. Nothing outside
# the droplet should reach an unauthenticated model server, and ufw does not
# open 11434, so this is the second lock on that door. Users who want remote
# access should tunnel over SSH, not change this.
Environment="OLLAMA_HOST=127.0.0.1:11434"
# Coding agents and long-document work need far more than the 4096-token
# default; 64K is the smallest window that keeps tools like OpenCode usable.
# It is charged against VRAM per loaded model, so lower it if you would rather
# spend that memory on a larger model.
Environment="OLLAMA_CONTEXT_LENGTH=65536"
EOF
sudo systemctl daemon-reload
sudo systemctl enable ollama.service
sudo systemctl restart ollama.service

# The pulls below go through the running server, which is what puts the blobs
# in the service's own OLLAMA_MODELS directory with the right ownership.
# Pulling as the build user instead would write them to ~/.ollama, where the
# service cannot see them and the cleanup script would not account for them.
for i in $(seq 1 30); do
  curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS http://127.0.0.1:11434/api/version >/dev/null ||
  { echo "Error: ollama did not become ready" >&2; systemctl status ollama.service --no-pager | tail -20 >&2; exit 1; }

if [[ -z ${MODELS// /} ]]; then
  echo "==> No models requested (ollama_models is empty); skipping downloads"
else
  echo "==> Preloading models (free space now: $(df -h --output=avail / | tail -1 | tr -d ' '))"
  for m in $MODELS; do
    echo "    pulling ${m}"
    # Progress is written with carriage returns, which would otherwise arrive
    # as one enormous line in the packer log; keep just the final state.
    if ! ollama pull "$m" 2>&1 | tr '\r' '\n' | tail -1 | sed 's/^/      /'; then
      echo "Error: failed to pull ${m}" >&2
      exit 1
    fi
  done
  echo "==> Models installed"
  ollama list 2>/dev/null | sed 's/^/    /'
  echo "    free space left: $(df -h --output=avail / | tail -1 | tr -d ' ')"
fi

echo "==> Ollama OK"
