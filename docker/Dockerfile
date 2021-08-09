FROM ubuntu:19.08

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
    chmod +x makefile bin/*

ENTRYPOINT [ "python3", "db-lib-gen.py" ]
