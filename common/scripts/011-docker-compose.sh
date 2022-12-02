#!/bin/sh

mkdir -p ~/.docker/cli-plugins/;
curl -SL https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose;
chmod +x ~/.docker/cli-plugins/docker-compose;
