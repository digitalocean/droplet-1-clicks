#!/bin/sh

template_dir=_template
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
  label=$2
  image_label="${name}-${label}"

  if [ -d "$image_label" ]
  then
    echo "$image_label directory already exists" > /dev/stderr

    exit 1
  fi

  cp -r "$template_dir" "$image_label"

  < "$template_dir/$build_template" \
  sed \
    -e "s#{{OS_VERSION}}#${label}#g;" \
    -e "s#{{IMAGE_LABEL}}#${image_label}#g;" \
  > "$image_label/template.json"
}

create "$@"
