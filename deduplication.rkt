#lang racket/base

(require file/unzip
         openssl/sha1
         racket/file
         racket/format
         racket/match
         racket/path
         racket/port
         "common.rkt"
         "sugar.rkt")

(provide
 dedupe-snapshot
 fix-catalog-checksums)

(define-logger deduper)

;; Zip files record the modification times of each file contained
;; within them so hashing them does not produce deterministic values.
;; Instead, we must sort the files by name and then hash the contents
;; of the files within the zips themselves, which is what this
;; function does.
(define (zip-digest path)
  (call-with-unzip path
    (lambda (temp-path)
      (define-values (in out)
        (make-pipe))

      (define sorted-paths
        (sort (find-files
               file-exists?
               temp-path)
              path<?))

      (thread
       (lambda ()
         (for ([p (in-list sorted-paths)])
           (call-with-input-file p
             (lambda (f-in)
               (copy-port f-in out))))
         (close-output-port out)))

      (sha1 in))))

(define (find-pkg-archives snapshot-path)
  (find-files
   (lambda (p)
     (equal? (path-get-extension p) #".zip"))
   (build-path snapshot-path "pkgs")))

(define (make-checksum path)
  (define checksum-path (path-add-extension path #".CHECKSUM" #"."))
  (define target-digest (call-with-input-file path sha1))
  (with-output-to-file checksum-path
    #:exists 'replace
    (lambda ()
      (display target-digest))))

(define (dedupe-snapshot snapshot-path store-path)
  (for ([path (in-list (find-pkg-archives snapshot-path))] #:unless (link-exists? path))
    (define content-digest (zip-digest path))
    (match-define (list _ d1 d2 fn)
      (regexp-match #rx"(..)(..)(.+)" content-digest))

    (define target-path (build-path store-path d1 d2 fn))
    (log-deduper-debug "deduplicating ~a to ~a" path target-path)
    (make-directory* (path-only target-path))
    (if (file-exists? target-path)
        (delete-file path)
        (rename-file-or-directory path target-path #t))
    (make-file-or-directory-link target-path path)
    (make-checksum path)))

(define (fix-catalog-checksums snapshot-path)
  (define catalog-path (build-path snapshot-path "catalog"))
  (define pkgs-path (build-path catalog-path "pkg"))
  (define pkgs-all
    (for/hash ([path (in-list (directory-list pkgs-path #:build? #t))])
      (define metadata (call-with-input-file path read))
      (define source-path (simplify-path (build-path catalog-path ('source metadata))))
      (define checksum-path (path-add-extension source-path #".CHECKSUM" #"."))
      (define checksum (call-with-input-file checksum-path port->string))
      (define updated-metadata
        (~> metadata
            (hash-set 'checksum checksum)
            (hash-set 'versions (hash 'default (hash 'checksum checksum
                                                     'source ('source metadata))))))
      (write/rktd path updated-metadata)
      (values ('name metadata) updated-metadata)))

  (write/rktd (build-path snapshot-path "catalog" "pkgs-all") pkgs-all))
