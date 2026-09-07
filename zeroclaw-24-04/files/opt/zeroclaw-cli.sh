#!/bin/bash
# Preserve quoting when forwarding args to zeroclaw as the service user.
cmd=$(printf '%q ' zeroclaw "$@")
su - zeroclaw -c "$cmd"
