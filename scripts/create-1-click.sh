#!/bin/sh

build_template=template.json

exit_err() {
  usage="Usage: create-1-click.sh <1-click-name> <image-label>"

  echo "$usage" > /dev/stderr
  exit 1
}

create() {
  if [ $# != 2 ]
  then
    exit_err
  fi

  name=$1
  image_label=$2

  if [ -d "$image_label" ]
  then
    echo "$image_label directory already exists" > /dev/stderr

    exit 1
  fi

  mkdir "$image_label" "$image_label/files" "$image_label/scripts"

  < "$build_template" \
  sed \
    -e "s#{{NAME}}#${name}#g;" \
    -e "s#{{IMAGE_LABEL}}#${image_label}#g;" \
  > "$image_label/template.json"
}

create "$@"
