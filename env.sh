#!/bin/bash

###############################################################################
# env.sh
#   Setup the MadGraph/Docker environment for generating dark brem vertex
#   libraries.
###############################################################################

_repo="tomeichlersmith/mg-dark-brem"
_tag="edge"
export MG_DOCKER_TAG="$_repo:$_tag"

if hash docker &> /dev/null
then
  # this system has docker installed

  # make sure we have image we want
  #docker pull ${MG_DOCKER_TAG}

  # define run command
  alias db-lib-gen='docker run --rm -it -v $(pwd):$(pwd) -u $(id -u $USER):$(id -g $USER) ${MG_DOCKER_TAG} --out $(pwd)'

elif hash singularity &> /dev/null
then
  #this system has singularity installed

  #move the cache
  export SINGULARITY_CACHEDIR=$(pwd)/.singularity
  mkdir -p ${SINGULARITY_CACHEDIR}

  #define the image
  export MG_SINGULARITY_IMG=$(pwd)/${_repo/\//_}_${_tag}.sif

  # make sure we have the image we want
  singularity build ${MG_SINGULARITY_IMG} docker://${MG_DOCKER_TAG} 

  # define run command
  #     we need to create and mount and large scratch directory for singularity to use for working
  alias db-lib-gen='mkdir -p /scratch/$USER && singularity run --no-home --bind $(pwd),/scratch/$USER:/working_dir ${MG_SINGULARITY_IMG} --out $(pwd)'

else
  echo "ERROR: Neither docker nor singularity are installed."
  return 127
fi

