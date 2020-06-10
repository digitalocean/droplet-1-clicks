#!/bin/sh

build_template=template.json

exit_err() {
  usage="Usage: create-1-click.sh <1-click-name>"

  echo "$usage" > /dev/stderr
  exit 1
}

create() {
  if [ $# != 1 ]
  then
    exit_err
  fi

  name=$1

  if [ -d "$name" ]
  then
    echo "$name directory already exists" > /dev/stderr

    exit 1
  fi

  mkdir "$name" "$name/files" "$name/scripts"

  < "$build_template" \
  sed \
    -e "s#{{NAME}}#${name}#g;" \
  > "$name/template.json"
}

create "$@"
