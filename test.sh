#!/usr/bin/env bash

set -euo pipefail

docker run \
       --rm \
       -it \
       -v"$(pwd)":/code \
       -v"$(pwd)"/cache:/root/.racket/download-cache \
       jackfirth/racket:7.6-cs-full racket /code/build.rkt /code/archive /code/store $@
