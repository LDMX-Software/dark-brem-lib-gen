FROM alpine:3.14

RUN apk update &&\
    apk add --no-cache \
      gcc \
      g++ \
      bash \
      perl \
      make \
      musl-dev \
      gfortran \
      python3 \
      py3-pip 

RUN python3 -m pip --no-cache-dir install --upgrade pip setuptools wheel 
RUN python3 -m pip --no-cache-dir install six numpy
      
COPY . /madgraph
RUN chmod 777 /madgraph/
WORKDIR /madgraph/
RUN find . -type d -exec chmod -R ugo=rwx {} \; &&\
    find . -type f -exec chmod -R ugo=rw  {} \; &&\
    chmod +x makefile bin/*

ENTRYPOINT [ "python3", "/madgraph/db-lib-gen.py" ]
#ENTRYPOINT ["/bin/bash", "-l", "-c"]
#CMD [ "bash", "-l" ]