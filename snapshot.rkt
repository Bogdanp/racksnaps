#lang racket/base

(require (except-in pkg/lib pkg-create pkg-stage)
         pkg/private/create
         pkg/private/stage
         racket/async-channel
         racket/file
         racket/future
         racket/match
         "deduplication.rkt"
         "http.rkt"
         "logging.rkt"
         "sugar.rkt")

(define-logger archive)
(define-logger setup)
(define-logger snapshot)
(define stop-logger (start-logger '(archive deduper pkg setup snapshot)))

(define all-pkgs
  (get "pkgs-all"))


;; archiving ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define STAGE_TIMEOUT
  (* 10 60 1000))

(define current-concurrency
  (make-parameter (* (processor-count) 2)))

(define (archive-package name)
  (define info (hash-ref all-pkgs name))
  (define source
    (cond
      [('versions info)
       => (lambda (versions)
            ;; TODO: Lookup current VM version first.
            ('source ('default versions)))]

      [else
       ('source info)]))

  (log-archive-info "staging package ~a with source ~a" name source)
  (define-values (_name path _checksum _remove? _module-paths)
    (pkg-stage
     #:quiet? #t
     #:in-place? #f
     #:use-cache? #t
     #:strip 'source
     (pkg-desc source #f name #f #f)))

  (values info path))

(define (archive-packages pkgs)
  (define sema (make-semaphore (current-concurrency)))
  (define out (make-async-channel (* (current-concurrency) 8)))
  (begin0 out
    (for ([name (in-list pkgs)])
      (thread
       (lambda ()
         (call-with-semaphore sema
           (lambda ()
             (define store-thd
               (thread
                (lambda ()
                  (with-handlers ([exn:fail? (lambda (e)
                                               (async-channel-put out (list 'error name e)))])
                    (define-values (info path)
                      (archive-package name))

                    (async-channel-put out (list 'archived name info path))))))

             (sync
              (handle-evt
               (alarm-evt (+ (current-inexact-milliseconds) STAGE_TIMEOUT))
               (lambda _
                 (kill-thread store-thd)
                 (async-channel-put out (list 'timeout name))))
              store-thd))))))))


;; snapshot ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define INFO_KEYS
  '(source checksum ring name author description tags dependencies modules version))

(define (remove-non-essential info)
  (for/hash ([(k v) (in-hash info)]
             #:when (member k INFO_KEYS))
    (values k v)))

(define (write/rktd path data)
  (log-snapshot-debug "writing ~a" path)
  (call-with-output-file path
    (lambda (out)
      (write data out))))

(define (snapshot-package name info path dest)
  (log-snapshot-debug "creating archive of ~a" name)
  (pkg-create
   'zip path
   #:pkg-name name
   #:dest dest
   #:quiet? #t)

  (define pkg-filename (format "~a.zip" name))
  (define pkg-src-path (build-path 'up "pkgs" pkg-filename))
  (define pkg-checksum (file->string (build-path dest (format "~a.CHECKSUM" pkg-filename))))
  (~> info
      (remove-non-essential)
      (hash-set 'source (path->string pkg-src-path))
      (hash-set 'checksum pkg-checksum)
      (hash-set 'versions (hasheq 'default (hasheq 'checksum pkg-checksum
                                                   'source (path->string pkg-src-path))))))

(define (snapshot-packages pkgs dest ch)
  (define total-pkgs (length pkgs))
  (define catalog-path (build-path dest "catalog"))
  (define catalog/pkg-path (build-path catalog-path "pkg"))
  (delete-directory/files catalog-path #:must-exist? #f)
  (make-directory* catalog/pkg-path)

  (define pkgs-path (build-path dest "pkgs"))
  (delete-directory/files pkgs-path #:must-exist? #f)
  (make-directory* pkgs-path)
  (define pkgs-all
    (for/fold ([pkgs-all (hash)])
              ([i (in-range total-pkgs)])
      (log-snapshot-info "progress: [~a/~a]" (add1 i) total-pkgs)
      (match (sync ch)
        [(list 'archived name info path)
         (with-handlers ([exn:fail?
                          (lambda (e)
                            (begin0 pkgs-all
                              (log-snapshot-error "failed to snapshot ~a~n  error: ~a" name (exn-message e))))])
           (define info* (snapshot-package name info path pkgs-path))
           (write/rktd (build-path catalog/pkg-path name) info*)
           (hash-set pkgs-all name info*))]

        [(list 'error name e)
         (begin0 pkgs-all
           (log-snapshot-warning "skipping ~a due to error ~a" name (exn-message e)))]

        [(list 'timeout name)
         (begin0 pkgs-all
           (log-snapshot-warning "skipping ~a due to timeout" name))])))

  (write/rktd (build-path catalog-path "pkgs") (sort (hash-keys pkgs-all) string<?))
  (write/rktd (build-path catalog-path "pkgs-all") pkgs-all))


(module+ main
  (require racket/cmdline)
  (command-line
   #:once-each
   [("-c" "--concurrency")
    concurrency
    "the maximum number of packages to archive at once"
    (current-concurrency (string->number concurrency))]
   #:args (snapshot-path store-path . pkgs)
   (file-stream-buffer-mode (current-output-port) 'line)
   (define packages-to-snapshot (if (null? pkgs) (hash-keys all-pkgs) pkgs))
   (log-snapshot-info "about to snapshot ~a packages with ~a concurrency" (length packages-to-snapshot) (current-concurrency))
   (define ch (archive-packages packages-to-snapshot))
   (snapshot-packages packages-to-snapshot snapshot-path ch)
   (dedupe-snapshot snapshot-path store-path)
   (stop-logger)))
