#!/bin/bash

# Get the latest version from the repo
tag_version=$(curl -s "https://api.github.com/repos/${REPO_NAME}/releases/latest" | jq -r '.tag_name')

# Remove the v from the version number
latest_version="${tag_version//v}"

# DO API call to get the current version
current_version=$(curl -s "https://api.digitalocean.com/api/v2/vendor-portal/apps?safe_name=${SAFE_NAME}" | jq -r '.apps | .[] | .custom_data | .version')


if [ "$current_version" == "$latest_version" ]; then
  echo "No update needed for ${REPO_NAME}"
  exit 0
else
  echo "Updating ${REPO_NAME} from ${current_version} to ${latest_version}"
  APP_VERSION=$latest_version packer build --only 'digitalocean.ubuntu-2204' .
fi

