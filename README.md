# racksnaps

This is a work in progress and not all packages work at this point.

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
        https://racksnaps.defn.io/snapshots/2020/05/01/catalog/ \
        https://pkgs.racket-lang.org \
        https://planet-compats.racket-lang.org

When building a web app in CI you might limit the catalog list to just
the release catalog (for packages in the main distribution) and the
snapshot:

    raco pkg config --set catalogs \
        https://download.racket-lang.org/releases/7.6/catalog/ \
        https://racksnaps.defn.io/snapshots/2020/05/01/catalog/

## License

    racksnaps is licensed under the 3-Clause BSD license.


[Racket Package Catalog]: https://pkgs.racket-lang.org/
