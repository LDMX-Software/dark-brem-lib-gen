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
  docker pull ${MG_DOCKER_TAG}

  # define run command
  alias mg-gen='docker run --rm -it -v $(pwd):$(pwd) -u $(id -u $USER):$(id -g $USER) ${MG_DOCKER_TAG} --out $(pwd)'

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
  alias mg-gen='singularity run --no-home --bind $(pwd) ${MG_SINGULARITY_IMG} --out $(pwd)'

else
  echo "ERROR: Neither docker nor singularity are installed."
  return 127
fi

###############################################################################
# generate-db-lib run_number
#   Generate a full dark brem vertex library using the input run number.
###############################################################################
function generate-db-lib() {
  # Let's generate a dark brem library for the input run number
  _run="$1"

  for ap_mass in "1" "0.1" "0.05" "0.01" "0.005" "0.001"
  do
    for electron_energy in "4.0" "3.8" "3.5" "3.25" "3.0" "2.8" "2.5" "2.0"
    do
      mg-gen -A $ap_mass -E $electron_energy -r $_run -N 20000
    done
  done
}
