FROM racket/racket:8.2-full

RUN  apt-get update \
  && apt-get install -y dumb-init

RUN  raco pkg config --set download-cache-max-files 1024000 \
  && raco pkg config --set download-cache-max-bytes 107374182400 \
  && raco pkg config --set trash-max-packages 0 \
  && raco pkg config --set trash-max-seconds 0
