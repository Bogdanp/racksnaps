#lang racket/base

(provide
 make-done-cookie
 write/rktd)

(define-logger common)

(define (make-done-cookie snapshot-path)
  (define cookie-path (build-path snapshot-path "catalog" "done"))
  (log-common-debug "creating ~a")
  (call-with-output-file cookie-path
    #:exists 'truncate/replace
    (lambda (out)
      (write 'done out))))

(define (write/rktd path data)
  (log-common-debug "writing ~a" path)
  (call-with-output-file path
    #:exists 'truncate/replace
    (lambda (out)
      (write data out))))
