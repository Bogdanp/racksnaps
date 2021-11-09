#lang at-exp racket/base

(require net/url
         pkg/lib
         racket/file
         racket/format
         racket/match
         racket/port
         racket/system
         "common.rkt"
         "deduplication.rkt"
         "logging.rkt"
         "sugar.rkt")

(define-logger build)
(define-logger docker)
(define-logger setup)
(define stop-logger (start-logger '(build common deduper docker pkg setup)))

(define docker
  (find-executable-path "docker"))

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
     "bogdanp/racksnaps-built:8.3"
     "dumb-init"
     "bash" "-c"
     @~a{
         set -euo pipefail
         raco pkg config --set catalogs \
           file://@|built-snapshot-path|/catalog/ \
           file://@|snapshot-path|/catalog/
         raco pkg install --batch --auto --fail-fast --no-docs @name
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

  (define total-pkgs (length names))
  (define pkgs-all
    (for/fold ([pkgs-all (hash)])
              ([name (in-list names)]
               [i (in-naturals 1)])
      (with-handlers ([exn:fail?
                       (lambda (e)
                         (begin0 pkgs-all
                           (log-build-error "failed to build ~a~n error: ~a" name (exn-message e))))])
        (define built?
          (build-package root-path snapshot-path built-snapshot-path name))
        (log-build-info "progress: [~a/~a]" i total-pkgs)
        (cond
          [built?
           (define info (call-with-input-file (build-path snapshot-path "catalog" "pkg" name) read))
           (define new-checksum (file->string (build-path built-pkgs-path (format "~a.zip.CHECKSUM" name))))
           (define new-info
             (~> info
                 (hash-set 'checksum new-checksum)
                 (hash-set 'versions (hasheq 'default (hasheq 'source ('source info)
                                                              'checksum new-checksum)))))
           (write/rktd (build-path built-catalog-path "pkg" name) new-info)
           (hash-set pkgs-all name new-info)]

          [else
           (begin0 pkgs-all
             (log-build-warning "failed to build ~a" name))]))))

  (write/rktd (build-path built-catalog-path "pkgs") (sort (hash-keys pkgs-all) string<?))
  (write/rktd (build-path built-catalog-path "pkgs-all") pkgs-all))

(define (sort/topological pkgs&deps)
  (reverse
   (let loop ([res null]
              [todo (hash-keys pkgs&deps)]
              [pkgs&deps pkgs&deps])
     (cond
       [(null? todo) res]
       [else
        (define pkg (car todo))
        (cond
          [(memq pkg res)
           (loop res (cdr todo) pkgs&deps)]

          [(null? (hash-ref pkgs&deps pkg null))
           (loop (cons pkg res) (cdr todo) pkgs&deps)]

          [else
           (loop res
                 (append (filter
                          (λ (dep-pkg)
                            (hash-has-key? pkgs&deps dep-pkg))
                          (hash-ref pkgs&deps pkg null))
                         todo)
                 (hash-set pkgs&deps pkg null))])]))))

(define (get-all-pkg-names/topological)
  (map symbol->string
       (sort/topological
        (for/hasheq ([(name details) (get-all-pkg-details-from-catalogs)])
          (values (string->symbol name)
                  (for/list ([dep (in-list (hash-ref details 'dependencies null))])
                    (string->symbol
                     (cond
                       [(string? dep) dep]
                       [(list? dep) (car dep)]
                       [else (raise-argument-error 'get-all-pkg-names/topological "(or/c string? list?)" dep)]))))))))

(module+ main
  (require racket/cmdline)
  (command-line
   #:args (root-path snapshot-path built-snapshot-path store-path . pkgs)
   (file-stream-buffer-mode (current-output-port) 'line)
   (parameterize ([current-pkg-catalogs (list (path->url (build-path snapshot-path "catalog")))])
     (define packages-to-build (if (null? pkgs) (get-all-pkg-names/topological) pkgs))
     (log-build-info "about to build ~a packages" (length packages-to-build))
     (build-packages root-path snapshot-path built-snapshot-path packages-to-build)
     (dedupe-snapshot built-snapshot-path store-path)
     (fix-catalog-checksums built-snapshot-path)
     (make-done-cookie built-snapshot-path)
     (stop-logger))))
