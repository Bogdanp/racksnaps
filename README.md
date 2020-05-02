# racksnaps

This is a work in progress and it may not be stable enough for general
use yet.

This code builds daily snapshots of the official Racket Package
Catalog.  The intent is to allow application developers to depend on
specific, unchanging sets of packages until they're ready to add more
and/or update their apps.

The snapshots are currently available at

* https://racksnaps.defn.io/snapshots/ for source snapshots and
* https://racksnaps.defn.io/built-snapshots/ for package snapshots
  built using regular Racket 7.6.

To develop against the snapshot from May 2nd, 2020 using Racket 7.6,
you might run the following command:

    raco pkg config --set catalogs \
        https://download.racket-lang.org/releases/7.6/catalog/ \
        https://racksnaps.defn.io/snapshots/2020/05/02/catalog/ \
        https://pkgs.racket-lang.org \
        https://planet-compats.racket-lang.org

When building a web app in CI you might limit the catalog list to just
the release catalog (for packages in the main distribution) and the
snapshot:

    raco pkg config --set catalogs \
        https://download.racket-lang.org/releases/7.6/catalog/ \
        https://racksnaps.defn.io/snapshots/2020/05/02/catalog/

To speed up builds, you might layer in the built-snapshot for that day:

    raco pkg config --set catalogs \
        https://download.racket-lang.org/releases/7.6/catalog/ \
        https://racksnaps.defn.io/built-snapshots/2020/05/02/catalog/ \
        https://racksnaps.defn.io/snapshots/2020/05/02/catalog/


## How it Works

Every day at 12am UTC, the service queries all the packages on
pkgs.racket-lang.org for metadata and source locations.  It then
creates a source package archive for each package whose sources are
still valid.

Once all the source package archives are created, "built" packages
(packages that contain source code, docs and compiled `.zo` files) are
created from those archives.  Each of these is compiled in isolation
and any packages that don't compile cleanly are excluded from the
final snapshot.

The packages are currently being built using Racket BC 7.6.  When 7.7
comes out, we'll switch to it for future builds and when Racket CS
becomes the default, we'll switch to it.

Snapshots are never modified once they succeed and a content
addressing scheme is used for the individual packages to avoid using
up too much disk space over time.

`snapshot.rkt` creates the "source" snapshots and `built-snapshot.rkt`
creates the "built" snapshots.


## License

    racksnaps is licensed under the 3-Clause BSD license.


[Racket Package Catalog]: https://pkgs.racket-lang.org/
