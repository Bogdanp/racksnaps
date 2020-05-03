#!/usr/bin/env bash

set -euo pipefail

docker run \
       --rm \
       -v"$(pwd)":"$(pwd)" \
       -v"$(pwd)"/cache:/root/.racket/download-cache \
       bogdanp/racksnaps:7.6 \
         dumb-init \
         racket \
         "$(pwd)/snapshot.rkt" \
         "$(pwd)/archive" \
         "$(pwd)/store" \
         $@

docker run \
       --rm \
       -v"$(pwd)":"$(pwd)" \
       -v"$(pwd)"/cache:/root/.racket/download-cache \
       -v/var/run/docker.sock:/var/run/docker.sock \
       bogdanp/racksnaps-built:7.6 \
         dumb-init \
         racket \
         "$(pwd)/built-snapshot.rkt" \
         "$(pwd)" \
         "$(pwd)/archive" \
         "$(pwd)/built-archive" \
         "$(pwd)/store" \
         $@
