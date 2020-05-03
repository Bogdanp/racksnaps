#lang at-exp racket/base

(require net/url
         pkg/lib
         racket/async-channel
         racket/file
         racket/format
         racket/future
         racket/match
         racket/port
         racket/system
         "deduplication.rkt"
         "logging.rkt"
         "sugar.rkt")

(define-logger build)
(define-logger docker)
(define-logger setup)
(define stop-logger (start-logger '(build deduper docker pkg setup)))

(define current-concurrency
  (make-parameter (processor-count)))

(define docker
  (find-executable-path "docker"))

(define (write/rktd path data)
  (log-build-debug "writing ~a" path)
  (call-with-output-file path
    (lambda (out)
      (write data out))))

(define BUILD_TIMEOUT
  (* 10 60 1000))

(define (build-package root-path snapshot-path built-snapshot-path name)
  (log-build-info "building package ~a" name)
  (match-define (list out _in _pid err control)
    (process*
     docker
     "run"
     "--rm"
     "--network" "none"
     "-e" "CI=1"
     "-e" "PLT_PKG_BUILD_SERVICE=1"
     (format "-v~a:~a" root-path root-path)
     "bogdanp/racksnaps-built:7.6"
     "dumb-init"
     "bash" "-c"
     @~a{
         set -euo pipefail
         raco pkg config --set catalogs \
           file://@|built-snapshot-path|/catalog/ \
           file://@|snapshot-path|/catalog/
         raco pkg install --batch --auto --fail-fast @name
         raco pkg create --built --dest @|built-snapshot-path|/pkgs --from-install @name
         }))

  (define logger-thd
    (thread
     (lambda ()
       (let loop ()
         (with-handlers ([exn:fail?
                          (lambda (e)
                            (log-docker-warning "~a~nerror: ~a" name (exn-message e)))])
           (sync
            (handle-evt
             (thread-receive-evt)
             void)
            (handle-evt
             (read-line-evt out)
             (lambda (line)
               (unless (eof-object? line)
                 (log-docker-debug "~a: ~a" name line))
               (loop)))
            (handle-evt
             (read-line-evt err)
             (lambda (line)
               (unless (eof-object? line)
                 (log-docker-warning "~a: ~a" name line))
               (loop)))))))))

  (sync
   (handle-evt
    (alarm-evt (+ (current-inexact-milliseconds) BUILD_TIMEOUT))
    (lambda _
      (control 'interrupt)))
   (thread
    (lambda ()
      (control 'wait))))

  (begin0 (eq? (control 'status) 'done-ok)
    (thread-send logger-thd 'stop)))

(define (build-packages root-path snapshot-path built-snapshot-path names)
  (define built-catalog-path (build-path built-snapshot-path "catalog"))
  (define built-pkgs-path (build-path built-snapshot-path "pkgs"))
  (delete-directory/files built-snapshot-path #:must-exist? #f)
  (make-directory* (build-path built-catalog-path "pkg"))
  (make-directory* built-pkgs-path)

  (define sema (make-semaphore (current-concurrency)))
  (define ch (make-async-channel (* (current-concurrency) 8)))
  (for ([name (in-list names)])
    (thread
     (lambda ()
       (call-with-semaphore sema
         (lambda ()
           (with-handlers ([exn:fail?
                            (lambda (e)
                              (log-build-error "failed to build ~a~n error: ~a" name (exn-message e))
                              (async-channel-put ch (list 'failed name)))])
             (define built?
               (build-package root-path snapshot-path built-snapshot-path name))

             (async-channel-put ch (if built?
                                       (list 'built name)
                                       (list 'failed name)))))))))

  (define total-pkgs (length names))
  (define pkgs-all
    (for/fold ([pkgs-all (hash)])
              ([i (in-range total-pkgs)])
      (log-build-info "progress: [~a/~a]" i total-pkgs)
      (match (sync ch)
        [(list 'built name)
         (define info (call-with-input-file (build-path snapshot-path "catalog" "pkg" name) read))
         (define new-checksum (file->string (build-path built-pkgs-path (format "~a.zip.CHECKSUM" name))))
         (define new-info
           (~> info
               (hash-set 'checksum new-checksum)
               (hash-set 'versions (hasheq 'default (hasheq 'source ('source info)
                                                            'checksum new-checksum)))))
         (write/rktd (build-path built-catalog-path "pkg" name) new-info)
         (hash-set pkgs-all name new-info)]

        [(list 'failed name)
         (begin0 pkgs-all
           (log-build-warning "failed to build ~a" name))])))

  (write/rktd (build-path built-catalog-path "pkgs") (sort (hash-keys pkgs-all) string<?))
  (write/rktd (build-path built-catalog-path "pkgs-all") pkgs-all))


(module+ main
  (require racket/cmdline)
  (command-line
   #:once-each
   [("-c" "--concurrency")
    concurrency
    "the maximum number of packages to archive at once"
    (current-concurrency (string->number concurrency))]
   #:args (root-path snapshot-path built-snapshot-path store-path . pkgs)
   (file-stream-buffer-mode (current-output-port) 'line)
   (parameterize ([current-pkg-catalogs (list (path->url (build-path snapshot-path "catalog")))])
     (define packages-to-build (if (null? pkgs) (get-all-pkg-names-from-catalogs) pkgs))
     (log-build-info "about to build ~a packages with ~a concurrency" (length packages-to-build) (current-concurrency))
     (build-packages root-path snapshot-path built-snapshot-path packages-to-build)
     (dedupe-snapshot built-snapshot-path store-path)
     (stop-logger))))
