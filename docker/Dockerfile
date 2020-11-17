FROM ubuntu:18.04

RUN apt-get update &&\
    apt-get install -y \
      make \
      gfortran 
      
COPY . /madgraph
WORKDIR /madgraph/
RUN find . -type d -exec chmod -R ugo=rwx {} \; &&\
    find . -type f -exec chmod -R ugo=rw  {} \; &&\
    chmod +x makefile mg-gen.sh bin/*

ENTRYPOINT [ "./mg-gen.sh" ]
