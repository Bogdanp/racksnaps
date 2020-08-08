#!/usr/bin/env bash

set -euo pipefail

VERSION=7.8
SNAPSHOT_IMAGE="bogdanp/racksnaps:$VERSION"
BUILT_SNAPSHOT_IMAGE="bogdanp/racksnaps-built:$VERSION"
SNAPSHOT="$(date +%Y)/$(date +%m)/$(date +%d)"
ROOT_PATH="/var/racksnaps"
CODE_PATH="/opt/racksnaps"
CACHE_PATH="$ROOT_PATH/cache"
SNAPSHOT_PATH="$ROOT_PATH/snapshots/$SNAPSHOT"
SNAPSHOT_LOG_PATH="$SNAPSHOT_PATH.log"
BUILT_SNAPSHOT_PATH="$ROOT_PATH/built-snapshots/$SNAPSHOT"
BUILT_SNAPSHOT_LOG_PATH="$BUILT_SNAPSHOT_PATH.log"
STORE_PATH="$ROOT_PATH/store"

rm -rf   "$SNAPSHOT_PATH" "$BUILT_SNAPSHOT_PATH"
mkdir -p "$SNAPSHOT_PATH" "$BUILT_SNAPSHOT_PATH"

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

docker run \
       --rm \
       -v"$ROOT_PATH":"$ROOT_PATH" \
       -v"$CODE_PATH":/code \
       -v"$CACHE_PATH":/root/.racket/download-cache \
       -v/var/run/docker.sock:/var/run/docker.sock \
       "$BUILT_SNAPSHOT_IMAGE" \
       dumb-init \
         racket \
         /code/built-snapshot.rkt \
         "$ROOT_PATH" \
         "$SNAPSHOT_PATH" \
         "$BUILT_SNAPSHOT_PATH" \
         "$STORE_PATH" | tee "$BUILT_SNAPSHOT_LOG_PATH"
