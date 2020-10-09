#!/bin/sh

wget "https://raw.githubusercontent.com/dokku/dokku/v${dokku_version}/bootstrap.sh"
DOKKU_TAG="v${dokku_version}" bash bootstrap.sh
