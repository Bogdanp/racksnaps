#!/usr/bin/env bash

set -euo pipefail

VERSION=8.2
SNAPSHOT_IMAGE="bogdanp/racksnaps:$VERSION"
SNAPSHOT="$(date +%Y)/$(date +%m)/$(date +%d)"
ROOT_PATH="/var/racksnaps"
CODE_PATH="/opt/racksnaps"
CACHE_PATH="$ROOT_PATH/cache"
SNAPSHOT_PATH="$ROOT_PATH/snapshots/$SNAPSHOT"
SNAPSHOT_LOG_PATH="$SNAPSHOT_PATH.log"
STORE_PATH="$ROOT_PATH/store"

rm -rf   "$SNAPSHOT_PATH"
mkdir -p "$SNAPSHOT_PATH"

docker run \
       --rm \
       -v"$ROOT_PATH":"$ROOT_PATH" \
       -v"$CODE_PATH":/code \
       -v"$CACHE_PATH":/root/.racket/download-cache \
       "$SNAPSHOT_IMAGE" \
       dumb-init \
         racket \
         /code/snapshot.rkt \
         "$SNAPSHOT_PATH" \
         "$STORE_PATH" | tee "$SNAPSHOT_LOG_PATH"
