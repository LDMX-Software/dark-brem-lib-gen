FROM ubuntu:18.04

RUN apt-get update &&\
    apt-get install -y \
      make \
      gfortran \
      python3
      
COPY . /madgraph
RUN chmod 777 /madgraph/
WORKDIR /madgraph/
RUN find . -type d -exec chmod -R ugo=rwx {} \; &&\
    find . -type f -exec chmod -R ugo=rw  {} \; &&\
    chmod +x makefile db-lib-gen.sh bin/*

ENTRYPOINT [ "python3", "/madgraph/db-lib-gen.py" ]
