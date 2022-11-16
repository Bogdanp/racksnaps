# racksnaps

<p align="left">
  <a href="https://github.com/Bogdanp/racksnaps/actions?query=workflow%3A%22CI%22"><img alt="GitHub Actions status" src="https://github.com/Bogdanp/racksnaps/workflows/CI/badge.svg"></a>
</p>

This code builds daily snapshots of the official [Racket Package
Catalog].  The intent is to allow application developers to depend on
specific, unchanging sets of packages until they're ready to update
their apps.

The snapshots are currently available at https://racksnaps.defn.io/snapshots/ .

To develop against the snapshot from November 16th, 2022, you might
run the following command:

    raco pkg config --set catalogs \
        https://download.racket-lang.org/releases/8.7/catalog/ \
        https://racksnaps.defn.io/snapshots/2022/11/16/catalog/ \
        https://pkgs.racket-lang.org \
        https://planet-compats.racket-lang.org

When building a web app in CI you might limit the catalog list to just
the release catalog (for packages in the main distribution) and the
snapshot:

    raco pkg config --set catalogs \
        https://download.racket-lang.org/releases/8.7/catalog/ \
        https://racksnaps.defn.io/snapshots/2022/11/16/catalog/


## How it Works

Every day at 12am UTC, the service queries all the packages on
pkgs.racket-lang.org for metadata and source locations.  It then
creates a source package archive for each package whose sources are
still valid.

Snapshots are never modified once they succeed and a content
addressing scheme is used for the individual packages to avoid using
up too much disk space over time.

The `snapshot.rkt` program creates the snapshots.

## Testing Changes

The code relies on [Docker] so you'll need a system that supports it.

To run a full build, you can invoke

    ./test.sh

in the root of the repository.

To run a build for a subset of packages, you can invoke `test.sh` with
whichever packages you want to build:

    ./test.sh component component-lib component-doc


## License

    racksnaps is licensed under the 3-Clause BSD license.


[Racket Package Catalog]: https://pkgs.racket-lang.org/
[Docker]: https://www.docker.com/
