#!/bin/bash

set -e

curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=${OLLAMA_VERSION} sh

sudo -u digitalocean bash <<EOF
echo "Now installing Open Web UI"

cd ~
source /home/digitalocean/anaconda3/etc/profile.d/conda.sh

conda create -n ui python=3.11 --yes
conda activate ui

yes| pip install  pip --upgrade
yes| pip install  open-webui==${OPEN_WEBUI_VERSION}

conda deactivate
EOF

ollama pull ${MODEL_NAME}
