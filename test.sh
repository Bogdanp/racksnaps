#!/usr/bin/env bash

set -euo pipefail

docker run \
       --rm \
       -it \
       -v"$(pwd)":/code \
       -v"$(pwd)"/cache:/root/.racket/download-cache \
       bogdanp/racksnaps:7.6 racket /code/snapshot.rkt /code/archive /code/store $@
