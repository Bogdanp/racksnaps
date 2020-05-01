#!/usr/bin/env bash

set -euo pipefail

IMAGE=jackfirth/racket:7.6-full
SNAPSHOT="$(date +%Y)/$(date +%m)/$(date +%d)"
ROOT_PATH="/var/racksnaps"
CODE_PATH="/opt/racksnaps"
CACHE_PATH="$ROOT_PATH/cache"
SNAPSHOT_PATH="$ROOT_PATH/snapshots/$SNAPSHOT"
LOG_PATH="$SNAPSHOT_PATH.log"
STORE_PATH="$ROOT_PATH/store"

rm -rf "$SNAPSHOT_PATH"
mkdir -p "$SNAPSHOT_PATH"

docker run \
       --rm \
       -v"$ROOT_PATH":"$ROOT_PATH" \
       -v"$CODE_PATH":/code \
       -v"$CACHE_PATH":/root/.racket/download-cache \
       "$IMAGE" \
       racket /code/build.rkt "$SNAPSHOT_PATH" "$STORE_PATH" | tee "$LOG_PATH"
