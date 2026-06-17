#!/bin/bash

if [ $SUBMIT_MP == true ]; then
  echo "Submitting to MP"

  # Get the newly created imageID from the manifest
  IMG_ID=$(jq '.builds[-1].artifact_id | split(":")[1] | tonumber' manifest.json)

  # Create the update using the marketplace API
  curl -X PATCH -H "Content-Type: application/json" -H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" -d "{\"reasonForUpdate\": \"new version\", \"version\": \"${APP_VERSION}\", \"imageId\": ${IMG_ID}}" https://api.digitalocean.com/api/v1/vendor-portal/apps/${APP_ID}/versions/${APP_VERSION}

else
  echo "Skip submitting to MP"
  exit 0
fi
