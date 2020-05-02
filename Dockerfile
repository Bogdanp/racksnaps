FROM jackfirth/racket:7.6-full

RUN  raco pkg config --set download-cache-max-files 1024000 \
  && raco pkg config --set download-cache-max-bytes 107374182400 \
  && raco pkg config --set trash-max-packages 0 \
  && raco pkg config --set trash-max-seconds 0
