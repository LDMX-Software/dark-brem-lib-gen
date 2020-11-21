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
#   Generate a full dark brem vertex library using the input A' mass and run number.
#
#   Output: Archive named 'LDMX_W_UndecayedAP_mA_<mass>_run_<run>.tar.gz'
#           that contains a library of DB events for the input mass
#           and run number inside of a directory.
###############################################################################
function generate-db-lib() {
  _mass="$1"
  _run="$2"
  _extra_mg_gen_options="${@:3}"

  for electron_energy in "4.0" "3.8" #"3.5" "3.25" "3.0" "2.8" "2.5" "2.0"
  do
    mg-gen -A $_mass -E $electron_energy -r $_run -N 20000 $_extra_mg_gen_options
  done

  _library_name=LDMX_W_UndecayedAP_mA_${_mass}_run_${_run}
  tar czf ${_library_name}.tar.gz ${_library_name}/
}
