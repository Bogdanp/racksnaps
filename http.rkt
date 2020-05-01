#lang racket/base

(require net/http-client
         racket/format
         racket/match
         racket/port
         racket/string)

(provide get)

(define conn
  (http-conn-open
   "pkgs.racket-lang.org"
   #:ssl? #t
   #:port 443
   #:auto-reconnect? #t))

(define (get . path)
  (define-values (status _headers in)
    (http-conn-sendrecv! conn (~a "/" (string-join path  "/"))))

  (match status
    [(regexp #rx"HTTP.... 200 ")
     (read in)]

    [(regexp #rx"HTTP.... [345].. ")
     (error 'get "failed to get path:~n  path: ~a~n  response: ~a" path (port->bytes in))]))
