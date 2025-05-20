FROM alpine:3.21

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

# MG5_aMC v3 needs python's following modules 
RUN python3 -m pip --no-cache-dir install --upgrade pip setuptools wheel 
RUN python3 -m pip --no-cache-dir install six numpy

COPY . /madgraph

WORKDIR /madgraph/

RUN find . -type d -exec chmod -R ugo=rwx {} \; &&\
    find . -type f -exec chmod -R ugo=rw  {} \; &&\
    chmod +x makefile bin/* SubProcesses/survey.sh

ENV PATH=${PATH}:/madgraph/bin
