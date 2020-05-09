#lang racket/base

(require file/unzip
         openssl/sha1
         racket/file
         racket/format
         racket/match
         racket/path
         racket/port)

(provide
 dedupe-snapshot)

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

(define (dedupe-snapshot snapshot-path store-path)
  (define all-pkg-archives
    (find-files
     (lambda (p)
       (equal? (path-get-extension p) #".zip"))
     (build-path snapshot-path "pkgs")))
  (for ([path (in-list all-pkg-archives)])
    (when (link-exists? path)
      (error 'dedupe-snapshot "path ~a is already a link" path))

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

    (define checksum-path (~a path ".CHECKSUM"))
    (define target-digest (call-with-input-file target-path sha1))
    (log-deduper-debug "affixing ~a to ~a" checksum-path target-digest)
    (with-output-to-file checksum-path
      #:exists 'truncate/replace
      (lambda ()
        (display target-digest)))))
