#lang racket/base

(require file/sha1
         pkg/lib
         racket/cmdline
         racket/file
         racket/future
         racket/match
         racket/path
         setup/matching-platform
         setup/setup
         "http.rkt"
         "logging.rkt")

(define-logger snapshot)
(define stop-logger (start-logger '(snapshot)))

(define all-pkg-names
  (sort (get "pkgs") string<?))

(define installed-packages
  (make-hash (for/list ([pkg (append
                              (installed-pkg-names #:scope #f)
                              (installed-pkg-names #:scope 'installation)
                              (installed-pkg-names #:scope 'user))])
               (cons pkg #t))))

(define failed-packages
  (make-hash))

(define (installed? name)
  (hash-has-key? installed-packages name))

(define (failed? name)
  (hash-has-key? failed-packages name))

(define (min-version-met? v)
  (and (string? v)
       (string>=? (version) v)))

(define (platform-met? s)
  (and (platform-spec? s)
       (matching-platform? s)))

(define (build collects)
  (setup #:collections (and collects
                            (for/list ([s (in-list collects)])
                              (if (list? s) s (list s))))
         #:jobs (processor-count)
         #:make-docs? #f
         #:make-doc-index? #f))

(define (install-package name)
  (define info (get "pkg" name))
  (define deps (hash-ref info 'dependencies null))
  (define src
    (cond
      [(hash-ref (hash-ref info 'versions (hasheq)) 'default #f)
       => (lambda (ver)
            (hash-ref ver 'source))]

      [else
       (hash-ref info 'source)]))

  (log-snapshot-info
   "processing package: ~a progress: [~a/~a]"
   name
   (+ (hash-count installed-packages)
      (hash-count failed-packages))
   (length all-pkg-names))

  (cond
    [(failed? name)
     (log-snapshot-warning "skipping ~a because it has already failed to install" name)]

    [(installed? name)
     (log-snapshot-debug "skipping ~a because it has already been installed" name)]

    [(ormap failed? deps)
     (log-snapshot-warning "skipping ~a because it has failed dependencies~n" name)
     (hash-set! failed-packages name #t)]

    [else
     (hash-set! installed-packages name #t)
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (log-snapshot-error (exn-message e))
                        (hash-set! failed-packages name #t)
                        (hash-remove! installed-packages name))])
       (for ([dep (in-list deps)]
             #:unless (installed? dep)
             #:unless (failed? dep))
         (log-snapshot-debug "found missing dependency ~.s" dep)
         (match dep
           [(? string?)
            (install-package dep)]

           [(or (list name           (? min-version-met?))
                (list name #:version (? min-version-met?))
                (list name #:version (? min-version-met?) #:platform (? platform-met?))
                (list name                                #:platform (? platform-met?))
                (list name #:version (? min-version-met?) #:platform (? platform-met?)))
            (install-package name)]

           [_
            (log-snapshot-warning "skipping dep ~.s due to unrecognized spec" dep)]))

       (define desc (pkg-desc src #f name #f #f))
       (define collects
        (with-pkg-lock
          (pkg-install (list desc))))

       (define success?
         (build collects))

       (cond
         [success?
          (log-snapshot-info "successfully installed ~a" name)]

         [else
          (with-pkg-lock
            (pkg-remove (list name)))
          (log-snapshot-warning "failed to build ~a" name)]))]))

(define (compile-snapshot path)
  (pkg-archive-pkgs path
                    (hash-keys installed-packages)
                    #:include-deps? #t
                    #:relative-sources? #t))

(define (dedupe-snapshot snapshot-path store-path)
  (define all-pkg-archives
    (find-files
     (lambda (p)
       (equal? (path-get-extension p) #".zip"))
     (build-path snapshot-path "pkgs")))
  (for ([path (in-list all-pkg-archives)])
    (when (link-exists? path)
      (error 'dedupe-snapshot "path ~a is already a link" path))

    (define digest (call-with-input-file path sha1))
    (match-define (list _ d1 d2 fn)
      (regexp-match #rx"(..)(..)(.+)" digest))

    (define target-path (build-path store-path d1 d2 fn))
    (log-snapshot-debug "deduplicating ~a to ~a" path target-path)
    (make-directory* (path-only target-path))
    (rename-file-or-directory path target-path #t)
    (make-file-or-directory-link target-path path)))

(command-line
 #:args (snapshot-path store-path)
 (for-each install-package all-pkg-names)
 (compile-snapshot snapshot-path)
 (dedupe-snapshot snapshot-path store-path))
