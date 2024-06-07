#!/bin/sh

mkdir -p ~/.docker/cli-plugins/;
if [ -z "${docker_compose_version}" ]; then
  docker_compose_version=$(curl -sSL "https://api.github.com/repos/docker/compose/releases/latest" | jq -r '.tag_name');
fi
curl -SL https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose;
chmod +x ~/.docker/cli-plugins/docker-compose;
