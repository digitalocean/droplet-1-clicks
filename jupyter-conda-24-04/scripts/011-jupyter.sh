#!/bin/bash

set -e

echo "jupyterlab" >> /etc/jupyter/requirements.txt
echo "jupyter-ai" >> /etc/jupyter/requirements.txt

# JUPYTER
sudo -u anaconda bash <<EOF
echo "Now installing jupyter environment"

cd ~
source /home/anaconda/anaconda3/etc/profile.d/conda.sh

yes | conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
yes | conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
yes | conda tos accept --channel conda-forge

conda create -n jupyter python --yes
conda run -n jupyter pip install --upgrade pip
conda run -n jupyter pip install -r /etc/jupyter/requirements.txt
EOF

# Stable Diffusion 1.5
sudo -u anaconda bash <<EOF
echo "Now installing stable diffusion 1.5 environment"

mkdir /home/anaconda/examples
cd /home/anaconda/examples

git clone https://github.com/bes-dev/stable_diffusion.openvino.git
cd /home/anaconda/examples/stable_diffusion.openvino
source /home/anaconda/anaconda3/etc/profile.d/conda.sh

yes | conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
yes | conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
yes | conda tos accept --channel conda-forge #not found

conda create -n stable-diffusion-1.5 python=3.9 --yes
conda run -n stable-diffusion-1.5 pip install --upgrade pip
conda run -n stable-diffusion-1.5 pip install openvino-dev[onnx,pytorch]==2022.3.0
conda run -n stable-diffusion-1.5 pip install -r requirements.txt
conda run -n stable-diffusion-1.5 pip install ipykernel

conda run -n stable-diffusion-1.5 python -m ipykernel install --user --name stable-diffusion-1.5 --display-name "Stable Diffusion 1.5"
EOF

# Install Intel Openvino Tutorials
sudo -u anaconda bash <<EOF
echo "Now installing Intel Openvino notebooks and environment"

cd /home/anaconda/examples
git clone --depth=1 https://github.com/openvinotoolkit/openvino_notebooks.git
cd openvino_notebooks
sed -i 's/^jupyterlab/#jupyterlab/; s/^ipywidgets/#ipywidgets/; s/^ipykernel/#ipykernel/; s/^ipython/#ipython/' requirements.txt

source /home/anaconda/anaconda3/etc/profile.d/conda.sh

yes | conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
yes | conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
yes | conda tos accept --channel conda-forge

conda create -n openvino_notebooks python=3.10 --yes
conda run -n openvino_notebooks python -m pip install --upgrade pip
conda run -n openvino_notebooks pip install wheel setuptools
conda run -n openvino_notebooks pip install -r requirements.txt
conda run -n openvino_notebooks pip install ipykernel

conda run -n openvino_notebooks python -m ipykernel install --user --name openvino_notebooks --display-name "Openvino-Notebooks"

EOF
