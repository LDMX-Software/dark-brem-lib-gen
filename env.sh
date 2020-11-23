#!/bin/bash

###############################################################################
# env.sh
#   Setup the MadGraph/Docker environment for generating dark brem vertex
#   libraries.
###############################################################################

export _env_default_tag="edge"

env-help() {
  echo "Running Dark Brem Event Library Generation Container."
  echo "This script sets up the running environment using the dark brem event library generation container."
  echo "  Usage: source env.sh [-h,--help] [-p,--pull] [-t,--tag tag]"
  echo "    -h,--help : Print this help message."
  echo "    -p,--pull : Pull down the latest version of the image tag."
  echo "    -t,--tag  : tag is the image tag for the DockerHub repository (excluding the repository)."
  echo "              : Default: $_env_default_tag"
}

_repo="tomeichlersmith/dark-brem-lib-gen"
_tag=$_env_default_tag
_pull="OFF"

while [[ $# -gt 0 ]]
do
  option="$1"
  case "$option" in
    -h|--help)
      env-help
      return 0
      ;;
    -p|--pull)
      _pull="ON"
      shift
      ;;
    -t|--tag)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        echo "ERROR: '-t,--tag' requires an argument after it."
        return 1
      fi
      _tag="$2"
      shift
      shift
      ;;
    *)
      echo "ERROR: Unrecognized option: '%option'."
      return 2
      ;;
  esac
done

export MG_DOCKER_TAG="$_repo:$_tag"

if hash docker &> /dev/null
then
  # this system has docker installed

  # make sure we have image we want
  if [[ "$_pull" == *"ON"* || -z $(docker images -q ${MG_DOCKER_TAG} 2> /dev/null) ]]
  then
    docker pull ${MG_DOCKER_TAG}
  fi

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
  if [[ "$_pull" == *"ON"* || ! -f ${MG_SINGULARITY_IMG} ]]
  then
    singularity build --force ${MG_SINGULARITY_IMG} docker://${MG_DOCKER_TAG} 
  fi

  # define run command
  #     we need to create and mount and large scratch directory for singularity to use for working
  alias db-lib-gen='mkdir -p /scratch/$USER && singularity run --no-home --bind $(pwd),/scratch/$USER:/working_dir ${MG_SINGULARITY_IMG} --out $(pwd)'

else
  echo "ERROR: Neither docker nor singularity are installed."
  return 127
fi

