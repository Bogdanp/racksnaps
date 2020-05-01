# racksnaps

This code builds daily snapshots of the official Racket Package
Catalog.  The intent is to allow application developers to depend on
specific, unchanging sets of packages until they're ready to add more
and/or update their apps.

The snapshots are currently available at https://racksnaps.defn.io/snapshots/.

To use the snapshot from May 1st, 2020, you would run the following
command:

    raco pkg config --set catalogs \
        https://racksnaps.defn.io/snapshots/20200501/catalog/ \
        https://download.racket-lang.org/releases/7.6/catalog/ \
        https://pkgs.racket-lang.org \
        https://planet-compats.racket-lang.org

This is a work in progress and not all packages may work at this point.

## License

    racksnaps is licensed under the 3-Clause BSD license.


[Racket Package Catalog]: https://pkgs.racket-lang.org/
