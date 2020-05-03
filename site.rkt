#lang at-exp racket/base

(require (for-syntax racket/base
                     syntax/parse)
         racket/file
         racket/format
         web-server/dispatch
         web-server/http
         web-server/servlet-dispatch
         web-server/web-server
         "logging.rkt")


;; core ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (find-catalogs start)
  (define paths
    (find-files
     (lambda (p)
       (define-values (_snapshot-path filename _)
         (split-path p))

       (string=? (path->string filename) "catalog"))
     start))

  (sort (map path->string paths) string>?))


;; ui ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define STYLE #<<STYLE
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
}

.container {
  margin: 0 auto;
  width: 760px;
}

.title {
  margin: 16px 0;
  font-size: 2rem;
}

.row {
  display: grid;
  grid-auto-flow: column;
  grid-column-gap: 16px;
}

.column {
}

.para {
  margin: 16px 0;
}

.pre {
  background: #f9f9f9;
  display: block;
  padding: 8px;
  border-radius: 5px;
}

.section-title {
  padding: 8px 0;
}

.snapshot-list {
  list-style-position: inside;
}
STYLE
  )

(define script #<<SCRIPT
(function() {
  (function(n, e, m, E, a, $) {
    n[E]=n[E]||function(){(n[E].q=n[E].q||[]).push(arguments)};$=e.createElement(m);
    $.id=E;$.src=a;$.async=1;m=e.getElementsByTagName(m)[0];m.parentNode.insertBefore($,m)
  })(window, document, "script", "nemea", "https://racksnaps.nemea.co/track.js");

  nemea("view");
})();
SCRIPT
  )

(define (template
         #:subtitle [subtitle #f]
         . content)

  `(html
    (head
     (meta ([charset "utf-8"]))
     (title ,(if subtitle
                 @~a{racksnaps @'mdash @subtitle}
                 @~a{racksnaps}))
     (style ([type "text/css"]) ,STYLE))
    (body
     ,@content
     (script ,script))))

(define-syntax (define-container stx)
  (syntax-parse stx
    [(_ id:id)
     #:with id-str (datum->syntax #'id (symbol->string (syntax->datum #'id)))
     #'(define (id . content)
         `(div ([class id-str]) ,@content))]))

(define-syntax-rule (define-containers id0 id ...)
  (begin
    (define-container id0)
    (define-container id) ...))

(define-containers
  container
  row
  column)

(define (title s)
  `(h1 ([class "title"]) ,s))

(define (section-title s)
  `(h3 ([class "section-title"]) ,s))

(define (snapshot-list paths)
  `(ul
    ([class "snapshot-list"])
    ,@(for/list ([p (in-list paths)])
        (define p:str (~a "/" p "/"))
        `(li (a ([href ,p:str]) ,p:str)))))

(define (para . content)
  `(p ([class "para"]) ,@content))

(define (pre content)
  `(pre ([class "pre"]) ,content))

(define (anchor uri label)
  `(a ([href ,uri]) ,label))


;; pages ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define bp-url "https://defn.io")
(define gh-url "https://github.com/Bogdanp/racksnaps")

(define (home-page _req)
  (define latest-snaps (find-catalogs "snapshots"))
  (define latest-built-snaps (find-catalogs "built-snapshots"))

  (response/xexpr
   (template
    (container
     (title "Racksnaps")
     (row
      (column
       @para{Racksnaps builds daily snapshots of the official Racket
                       Package Catalog. The intent is to allow application developers
                       to depend on specific, unchanging sets of packages until
                       they're ready to update their apps.}

       @para{To develop against the snapshot from May 2nd, 2020 using Racket 7.6, you might run the following command:}

       (pre #<<EXAMPLE
raco pkg config --set catalogs \
    https://download.racket-lang.org/releases/7.6/catalog/ \
    https://racksnaps.defn.io/snapshots/2020/05/02/catalog/ \
    https://pkgs.racket-lang.org \
    https://planet-compats.racket-lang.org
EXAMPLE
            )

       @para{When building a web app in CI you might limit the catalog list to just the release catalog (for packages in the main distribution) and the snapshot:}

       (pre #<<EXAMPLE
raco pkg config --set catalogs \
    https://download.racket-lang.org/releases/7.6/catalog/ \
    https://racksnaps.defn.io/snapshots/2020/05/02/catalog/
EXAMPLE
            )

       @para{To speed up builds, you might layer in the built-snapshot for that day:}

       (pre #<<EXAMPLE
raco pkg config --set catalogs \
    https://download.racket-lang.org/releases/7.6/catalog/ \
    https://racksnaps.defn.io/built-snapshots/2020/05/02/catalog/ \
    https://racksnaps.defn.io/snapshots/2020/05/02/catalog/
EXAMPLE
            )

       @para{Racksnaps' infrastructure and development is supported by
       @anchor[bp-url]{Bogdan Popa} and the source code, along with
       more details about how snapshots are created, is
       @anchor[gh-url]{available on GitHub.}}))
     (row
      (column
       (section-title "Latest Snapshots")
       (snapshot-list latest-snaps))
      (column
       (section-title "Latest Built Snapshots")
       (snapshot-list latest-built-snaps)))))))

(define (not-found-page _req)
  (response/xexpr
   #:code 404
   '(h1 "Page Not Found")))

(define-values (app _)
  (dispatch-rules
   [("") home-page]
   [else not-found-page]))


(module+ main
  (define stop
    (serve
     #:port 8000
     #:dispatch (dispatch/servlet app)))

  (define stop-logger
    (start-logger '(GC app)))

  (with-handlers ([exn:break?
                   (lambda _
                     (stop)
                     (stop-logger))])
    (sync/enable-break never-evt)))
