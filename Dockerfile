FROM jackfirth/racket:7.6-full

RUN  raco pkg config --set download-cache-max-files 512000 \
  && raco pkg config --set download-cache-max-bytes 10737418240 \
  && raco pkg config --set trash-max-packages 0 \
  && raco pkg config --set trash-max-seconds 0
