#lang racket/base

(require mzlib/os
         racket/date
         racket/format
         racket/list
         racket/match)

(provide
 start-logger)

(define (start-logger topics)
  (define stopped (make-semaphore))
  (define receiver
    (apply make-log-receiver
           (current-logger)
           (flatten
            (for/list ([topic (in-list topics)])
              (list 'debug topic)))))

  (define (receive-logs)
    (sync
     (choice-evt
      (handle-evt receiver
                  (match-lambda
                    [(vector level message _ _)
                     (fprintf (current-output-port)
                              "[~a] [~a] [~a] ~a\n"
                              (pretty-date)
                              (~a (getpid) #:align 'right #:width 8)
                              (~a level #:align 'right #:width 7)
                              message)
                     (receive-logs)]))
      stopped)))

  (define thd
    (thread receive-logs))

  (lambda ()
    (sync (system-idle-evt))
    (semaphore-post stopped)
    (void (sync thd))))

(define (pretty-date)
  (define d (current-date))
  (define o (quotient (date-time-zone-offset d) 60))
  (~a (date-year d)
      "-"
      (padded (date-month d))
      "-"
      (padded (date-day d))
      " "
      (padded (date-hour d))
      ":"
      (padded (date-minute d))
      ":"
      (padded (date-second d))
      " UTC"
      (cond
        [(zero? o)     ""]
        [(negative? o) o]
        [else          (~a "+" o)])))

(define (padded n [w 2])
  (~r n #:min-width w #:pad-string "0"))
