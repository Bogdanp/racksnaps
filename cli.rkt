#lang racket/base

(module+ main
  (require racket/cmdline
           racket/file
           net/url
           json)

  (define config.rktd (build-path (current-directory) "etc/config.rktd"))

  (unless (file-exists? config.rktd)
    (define endpoint "https://racksnaps.defn.io/api/v1/catalogs")
    (define catalogs/jsexpr (read-json (get-pure-port (string->url endpoint))))
    (define latest-catalog-uri (hash-ref (list-ref catalogs/jsexpr 0) 'uri))
    (make-parent-directory* config.rktd)
    (call-with-output-file config.rktd
      (λ (to-file)
        (writeln (hash 'catalog (list latest-catalog-uri #f))
                 to-file)))))
