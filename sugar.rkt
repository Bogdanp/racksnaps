#lang racket/base

(require (for-syntax racket/base
                     syntax/parse))

(provide
 (rename-out [sugar-app #%app])
 ~>)

(define-syntax (sugar-app stx)
  (syntax-parse stx
    #:datum-literals (quote)
    [(_ (quote s) e)
     #'(hash-ref e 's #f)]

    [(_ . es)
     #'(#%app . es)]))

(define-syntax (~> stx)
  (syntax-parse stx
    [(_ e (f f-arg ...) (g g-arg ...) ...+)
     #'(~> (f e f-arg ...)
           (g g-arg ...) ...)]

    [(_ e (f f-arg ...))
     #'(f e f-arg ...)]))
