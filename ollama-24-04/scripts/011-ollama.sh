#!/bin/bash

set -e

curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=${OLLAMA_VERSION} sh

sudo -u digitalocean bash <<EOF
set -e
echo "Now installing Open Web UI"

cd ~
source /home/digitalocean/anaconda3/etc/profile.d/conda.sh

UI_ENV=/home/digitalocean/anaconda3/envs/ui
OPEN_WEBUI_BIN=\${UI_ENV}/bin/open-webui

conda create -p "\${UI_ENV}" python=3.11 --yes
conda run -p "\${UI_ENV}" pip install --upgrade pip
conda run -p "\${UI_ENV}" pip install "open-webui==${OPEN_WEBUI_VERSION}"

test -x "\${OPEN_WEBUI_BIN}" || {
  echo "ERROR: open-webui binary not found at \${OPEN_WEBUI_BIN}" >&2
  exit 1
}
EOF

systemctl enable ollama
systemctl start ollama

for i in $(seq 1 30); do
  if ollama list >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Ollama service did not become ready" >&2
    systemctl status ollama --no-pager || true
    exit 1
  fi
  sleep 2
done

ollama pull ${MODEL_NAME}
