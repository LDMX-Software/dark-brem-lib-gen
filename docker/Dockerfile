FROM alpine:3.14

RUN apk update &&\
    apk add --no-cache \
      bash \
      make \
      gfortran \
      python3
      
COPY . /madgraph
RUN chmod 777 /madgraph/
WORKDIR /madgraph/
RUN find . -type d -exec chmod -R ugo=rwx {} \; &&\
    find . -type f -exec chmod -R ugo=rw  {} \; &&\
    chmod +x makefile bin/* &&\
    /usr/local/bin/f95 --version

ENTRYPOINT [ "python3", "db-lib-gen.py" ]
