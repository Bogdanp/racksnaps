#lang at-exp racket/base

(require (for-syntax racket/base
                     syntax/parse)
         racket/file
         racket/format
         racket/match
         racket/string
         web-server/dispatch
         web-server/http
         web-server/servlet-dispatch
         web-server/web-server
         "logging.rkt")


;; core ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(struct catalog-cache-entry (paths deadline)
  #:transparent)

(define catalog-cache-entry-ttl 300)

(define (make-catalog-cache-entry paths)
  (catalog-cache-entry paths (+ (current-seconds) catalog-cache-entry-ttl)))

(define (deadline-passed? deadline)
  (>= (current-seconds) deadline))

(define catalog-cache (make-hash))
(define catalog-cache-mu (make-semaphore 1))

;; TODO: There should eventually be a limit on these.
(define (find-catalogs start)
  (call-with-semaphore catalog-cache-mu
    (lambda ()
      (match (hash-ref catalog-cache start #f)
        [(or #f (catalog-cache-entry _ (? deadline-passed?)))
         (define all-paths
           (find-files
            #:skip-filtered-directory? #t
            (lambda (p)
              (define-values (_snapshot-path filename _)
                (split-path p))

              (case (path->string filename)
                [("pkg" "pkgs") #f]
                [("catalog")    (file-exists? (build-path p "done"))]
                [else           (directory-exists? p)]))
            start))

         (define catalog-paths
           (for/list ([p (in-list all-paths)]
                      #:when (string-suffix? (path->string p) "/catalog"))
             (path->string p)))

         (define sorted-paths
           (sort catalog-paths string>?))

         (begin0 sorted-paths
           (hash-set! catalog-cache start (make-catalog-cache-entry sorted-paths)))]

        [(catalog-cache-entry paths _)
         paths]))))


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
     ,@content)))

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

  (response/xexpr
   (template
    (container
     (title "Racksnaps")
     (row
      (column
       @para{
             Racksnaps builds daily snapshots of the official Racket
             Package Catalog. The intent is to allow application
             developers to depend on specific, unchanging sets of
             packages until they're ready to update their apps.
             }

       @para{To develop against the snapshot from November 16th, 2022, you might run the following command:}

       (pre #<<EXAMPLE
raco pkg config --set catalogs \
    https://download.racket-lang.org/releases/8.7/catalog/ \
    https://racksnaps.defn.io/snapshots/2022/11/16/catalog/ \
    https://pkgs.racket-lang.org \
    https://planet-compats.racket-lang.org
EXAMPLE
            )

       @para{When building a web app in CI you might limit the catalog list to just the release catalog (for packages in the main distribution) and the snapshot:}

       (pre #<<EXAMPLE
raco pkg config --set catalogs \
    https://download.racket-lang.org/releases/8.7/catalog/ \
    https://racksnaps.defn.io/snapshots/2022/11/16/catalog/
EXAMPLE
            )

       @para{Racksnaps' infrastructure and development is supported by
       @anchor[bp-url]{Bogdan Popa} and the source code, along with
       more details about how snapshots are created, is
       @anchor[gh-url]{available on GitHub.}}))
     (row
      (column
       (section-title "Latest Snapshots")
       (snapshot-list latest-snaps)))))))

(define (catalogs-endpoint _req)
  (define ((catalog->jsexpr type) p)
    (match-define (list _ _ date)
      (regexp-match #px"^(built-)?snapshots/(..../../..)/catalog" p))
    (hasheq
     'date date
     'type (symbol->string type)
     'uri  (format "https://racksnaps.defn.io/~a/" p)))

  (define catalogs
    (sort
     (map (catalog->jsexpr 'source)
          (find-catalogs "snapshots"))
     string>? #:key (λ (e) (hash-ref e 'date))))

  (response/jsexpr catalogs))

(define (robots-txt-page _req)
  (response/output
   #:mime-type #"text/plain"
   (lambda (out)
     (displayln #<<ROBOTS
User-agent: *
Disallow: /built-snapshots/
Disallow: /snapshots/
ROBOTS
                out))))

(define (not-found-page _req)
  (response/xexpr
   #:code 404
   '(h1 "Page Not Found")))

(define-values (app _)
  (dispatch-rules
   [("") home-page]
   [("api" "v1" "catalogs") catalogs-endpoint]
   [("robots.txt") robots-txt-page]
   [else not-found-page]))


(module+ main
  (define stop
    (serve
     #:port 8000
     #:dispatch (dispatch/servlet app)))

  (define stop-logger
    (start-logger '(app)))

  (with-handlers ([exn:break?
                   (lambda _
                     (stop)
                     (stop-logger))])
    (sync/enable-break never-evt)))
