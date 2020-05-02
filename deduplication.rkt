#lang racket/base

(require file/sha1
         racket/file
         racket/match
         racket/path)

(provide
 dedupe-snapshot)

(define-logger deduper)

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
    (log-deduper-debug "deduplicating ~a to ~a" path target-path)
    (make-directory* (path-only target-path))
    (rename-file-or-directory path target-path #t)
    (make-file-or-directory-link target-path path)))
