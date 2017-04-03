#!/bin/sh

set -e # terminate on errors
CMD="$@" # the rest of the arguments should be ran at the bottom of the file/last

# Since Kubernetes stores secrets in separate files, where the file name is the
# secret name and it's contents is the actual secret, we need to go through all
# the files and export the key=value pairs of environment variables
# (provided SECRETS_PATH is set in Docker or Kubernetes environments)
if env | grep -q ^SECRETS_PATH= ; then
  for file in $SECRETS_PATH/* ; do
    # turns my-small-secret into MY_SMALL_SECRET
    key=$(basename "$file" | tr - _ | tr '[:lower:]' '[:upper:]')
    value=$(cat $file)
    export "$key=$value"
  done
fi

exec $CMD
