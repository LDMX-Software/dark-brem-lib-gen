#!/bin/bash

####################################################################################################
# dbgen-env.sh
#   This script is intended to define all the container aliases required
#   to interface with a dbgen-env container. These commands assume that the user
#     1. Has docker engine installed OR has singularity installed
#     2. Can run docker as a non-root user OR can run singularity build/run
#
#   SUGGESTION: Put something similar to the following in your '.bashrc',
#     '~/.bash_aliases', or '~/.bash_profile' so that you just have to 
#     run 'dbgen-env' to set-up this environment.
#
#   alias dbgen-env='source <full-path>/dbgen-env.sh; unalias dbgen-env'
#
#   The file $HOME/.dbgenrc handles the default environment setup for the
#   container. Look there for persisting your custom settings.
####################################################################################################

####################################################################################################
# All of this setup requires us to be in a bash shell.
#   We add this check to make sure the user is in a bash shell.
####################################################################################################
if tty -s; then
  if [[ "$0" != *"bash"* ]]; then
    echo "[dbgen-env.sh] [ERROR] You aren't in a bash shell. You are in '$0'."
    [[ "$SHELL" = *"bash"* ]] || echo "  You're default shell '$SHELL' isn't bash."
    return 1
  fi
fi

####################################################################################################
# __dbgen_has_required_engine
#   Checks if user has any of the supported engines for running containers
####################################################################################################
__dbgen_has_required_engine() {
  if hash docker &> /dev/null; then
    return 0
  elif hash singularity &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# check if user has a required engine
if ! __dbgen_has_required_engine; then
  echo "[dbgen-env.sh] [ERROR] You do not have docker or singularity installed!"
  return 1
fi

####################################################################################################
# We have gotten here after determining that we definitely have a container runner 
# (either docker or singularity) and we have determined how to connect the display 
# (or warn the user that we can't) via the DBGEN_CONTAINER_DISPLAY variable.
#
#   All container-runners need to implement the following commands
#     - __dbgen_container_clean : remove all containers and images on this machine
#     - __dbgen_container_config : print configuration of container
#     - __dbgen_run : give all arguments to container's entrypoint script
#         - mounts DBGEN_WORK (or /tmp/) to /working
#         - mounts DBGEN_DEST (or $(pwd)) to /output
#     - __dbgen_cache : change directory where image layers are cached
####################################################################################################

__dbgen_run_help() {
  cat<<\HELP
  USAGE:
    dbgen run [<args>]

    We launch the container, mounting all of the directories stored in the DBGEN_CONTAINER_MOUNTS
    array, and then execute the event library generation with its (optional) arguments <args>.

  EXAMPLES:
    Test run the container with all default arguments.
      dbgen run
HELP
}

__dbgen_cache_help() {
  cat <<\HELP
  USAGE:
    dbgen cache <dir>

    Change the directory in which layers of images are cached for later use.

    This feature is only available on systems using singularity.

  EXAMPLES:
    Perhaps my home directory is too small and so I need to use a large scratch directory.
      dbgen cache /scratch/
HELP
}

# prefer docker, so we do that first
if hash docker &> /dev/null; then
  # Print container configuration
  #   SHA retrieval taken from https://stackoverflow.com/a/33511811
  __dbgen_container_config() {
    echo "Docker Version: $(docker --version)"
    echo "Docker Tag: ${DBGEN_IMAGE_TAG}"
    echo "  SHA: $(docker inspect --format='{{index .RepoDigests 0}}' ${DBGEN_IMAGE_TAG})"
    return 0
  }

  # Clean up local machine
  __dbgen_container_clean() {
    docker container prune -f || return $?
    docker image prune -a -f  || return $?
  }

  # Run the container
  __dbgen_run() {
    docker run --rm -it 
      -v $(__dbgen_dest_mount) \
      -v $(__dbgen_work_mount) \
      -u $(id -u ${USER}):$(id -g ${USER}) \
      ${DBGEN_IMAGE_REPO}:${DBGEN_IMAGE_TAG} "$@"
    return $?
  }

  __dbgen_cache() {
    # Changing the image cache directory is only supported in singularity
    return 0
  }
elif hash singularity &> /dev/null; then
  # get image full name to pass to run command
  __dbgen_singularity_image() {
    echo "${DBGEN_SIF:-"docker://${DBGEN_IMAGE_REPO}:${DBGEN_IMAGE_TAG}"}"
  }

  # Print container configuration
  __dbgen_container_config() {
    echo "Singularity Version: $(singularity --version)"
    echo "Singularity Image: $(__dbgen_singularity_image)"
    return 0
  }

  # Clean up local machine
  __dbgen_container_clean() {
    [[ ! -z ${SINGULARITY_CACHEDIR} ]] && rm -r $SINGULARITY_CACHEDIR || return $?
  }

  # Run the container
  __dbgen_run() {
    singularity run --no-home --cleanenv \
      --bind $(__dbgen_dest_mount),$(__dbgen_work_mount) \
      $(__dbgen_singularity_image) "$@"
    return $?
  }

  __dbgen_cache() {
    if [[ -d "$1" ]]; then
      export SINGULARITY_CACHEDIR="$(cd "$1" && pwd -P)"
      return 0
    else
      echo "ERROR: '$1' is not a directory."
      return 1
    fi
  }
fi

####################################################################################################
# __dbgen_list
#   Get the docker tags for the repository
#   Taken from https://stackoverflow.com/a/39454426
# If passed repo-name is 'local',
#   the list of container options is runner-dependent
####################################################################################################
__dbgen_list_help() {
  cat<<\HELP
  USAGE:
    dbgen list [<glob>]

    <glob> is an optional globbing pattern (as in grep) to filter the list of image tags.

  EXAMPLES:
    List all of the tags in the default repository
      dbgen list
    Only look at the tags that are a version
      dbgen list "v*"
HELP
}
__dbgen_list() {
  local _glob="$1"
  #line-by-line description
  # download tag json
  # strip unnecessary information
  # break tags into their own lines
  # pick out tags using : as separator
  # get the tags matching the glob expression
  # put tags back onto same line
  wget -q https://registry.hub.docker.com/v1/repositories/${DBGEN_IMAGE_REPO}/tags -O -  |\
      sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' |\
      tr '}' '\n'  |\
      awk -F: '{print $3}' |\
      grep ${_glob:+*} |\
      tr '\n' ' '
  local rc=${PIPESTATUS[0]}
  echo "" #new line
  return ${rc}
}

####################################################################################################
# __dbgen_config
#   Print the configuration of the current setup
####################################################################################################
__dbgen_config() {
  echo "uname: $(uname -a)"
  echo "OSTYPE: ${OSTYPE}"
  echo "Destination: ${DBGEN_DEST:-"present working directory"}"
  echo "Working Dir: ${DBGEN_WORK:-"/tmp/"}"
  __dbgen_container_config
  return $?
}

####################################################################################################
# __dbgen_is_mounted
#   Check if the input directory will be accessible by the container
####################################################################################################
__dbgen_is_mounted() {
  local full=$(cd "$1" && pwd -P)
  for _already_mounted in ${DBGEN_CONTAINER_MOUNTS[@]}; do
    if [[ $full/ = $_already_mounted/* ]]; then
      return 0
    fi
  done
  return 1
}

####################################################################################################
# __dbgen_use
#  Define which image to use when launching container
####################################################################################################
__dbgen_use_help() {
  cat<<\HELP
  USAGE:
    dbgen use <image-tag>

    <image-tag> is the short-tag in the container image tag (the part after the colon).

    We do not check if the input tag is connected to an existing image.

  EXAMPLES:
    dbgen use latest
    dbgen use v2.1
HELP
}
export DBGEN_IMAGE_REPO="tomeichlersmith/dark-brem-lib-gen"
export DBGEN_IMAGE_TAG="latest"
unset DBGEN_SIF
__dbgen_use() {
  if [ -f "$1" ]; then
    # a SIF was provided
    export DBGEN_SIF="$(realpath "$1")"
  else
    export DBGEN_IMAGE_TAG="$1"
  fi
  return 0
}

####################################################################################################
# __dbgen_dest
#   Tell us to where the final event library should go.
####################################################################################################
__dbgen_dest_help() {
  cat<<\HELP
  USAGE:
    dbgen dest <directory>

    <directory> will be mounted to the container when it is run and it will
    be used as the root directory to output the event library generated by the dark brem
    program. By default, the output directory is the directory from which the program is run.

    The library is only copied to the destination directory after it is fully completed.

    An error is thrown if the input is not a directory.

  EXAMPLES:
    dbgen dest /my/data/dir
HELP
}
unset DBGEN_DEST
__dbgen_dest() {
  local _dir_to_mount="$1"

  if [[ ! -d $_dir_to_mount ]]; then
    echo "ERROR: $_dir_to_mount is not a directory!"
    return 1
  fi

  export DBGEN_DEST="$(cd "${_dir_to_mount}" && pwd -P)"
  return 0
}
# get the mount string for the destination directory
__dbgen_dest_mount() {
  echo "${DBGEN_DEST:-$(pwd -P)}:/output"
}

####################################################################################################
# __dbgen_work
#   Tell us to where the final event library should go.
####################################################################################################
__dbgen_work_help() {
  cat<<\HELP
  USAGE:
    dbgen work <directory>

    <directory> will be mounted to the container when it is run and it will
    be used as the working directory to write temporary files to during processing.
    The directory needs to be able to handle at least ~0.5GB of data and should 
    allow for more than that.

    By default, the /tmp/ directory is used.

    An error is thrown if the input is not a directory.

  EXAMPLES:
    dbgen dest /big/scratch/dir/
HELP
}
unset DBGEN_WORK
__dbgen_work() {
  local _dir_to_mount="$1"

  if [[ ! -d $_dir_to_mount ]]; then
    echo "ERROR: $_dir_to_mount is not a directory!"
    return 1
  fi

  export DBGEN_WORK="$(cd "${_dir_to_mount}" && pwd -P)"
  return 0
}
# get the mount string for the working directory
__dbgen_dest_mount() {
  echo "${DBGEN_WORK:-/tmp/}:/working"
}

####################################################################################################
# __dbgen_clean
#   Clean up the computing environment for dbgen
#   The input argument defines what should be cleaned
####################################################################################################
__dbgen_clean_help() {
  cat<<\HELP
  USAGE:
    dbgen clean (env | container | all)

    env       - unset the dbgen-env bash variables
    container - remove all containers and images from storage on this computer
    all       - do both 
HELP
}
__dbgen_clean() {
  _what="$1"
  case $_what in
    env|container|all)
      ;;
    *)
      echo "ERROR: '$_what' is an unrecognized dbgen clean option."
      return 1
      ;;
  esac

  local rc=0
  if [[ "$_what" = "container" ]] || [[ "$_what" = "all" ]]; then
    __dbgen_container_clean
    rc=$?
  fi

  if [[ "$_what" = "env" ]] || [[ "$_what" = "all" ]]; then
    unset DBGEN_DEST
    unset DBGEN_WORK
    unset DBGEN_SIF
    export DBGEN_IMAGE_REPO="tomeichlersmith/dark-brem-lib-gen"
    export DBGEN_IMAGE_TAG="latest"
  fi

  return ${rc}
}

####################################################################################################
# __dbgen_source
#   Run all the sub-commands in the provided file.
#   Ignore empty lines or lines starting with '#'
####################################################################################################
__dbgen_source_help() {
  cat<<\HELP
  USAGE:
    dbgen source <file>

    <file> has a list of commands in it that will each be given to the foundational 'dbgen' command.
    All empty lines and lines beginning with '#' are ignored.

    It is good practice to use full paths to directories and files inside of <file> because
    this command does not guartantee a location from which the commands in <file> are run.

  EXAMPLES:
    The dbgen-env.sh script uses this function to setup a default environment if the file $HOME/.dbgenrc
    exists.

      dbgen source $HOME/.dbgenrc
HELP
}
__dbgen_source() {
  if [[ ! -f "$1" ]]; then
    echo "ERROR: '$1' is not a file."
    return 1
  fi
  while read _subcmd; do
    if [[ -z "$_subcmd" ]] || [[ "$_subcmd" = \#* ]]; then
      continue
    fi
    dbgen $_subcmd || return $?
  done < $1
  cd - &> /dev/null
  return 0
}

####################################################################################################
# __dbgen_help
#   Print some helpful message to the terminal
####################################################################################################
__dbgen_help() {
  cat <<\HELP
  USAGE: 
    dbgen <command> [<argument> ...]

    <command> can either be an EXTERNAL command defined in the dbgen-env.sh script
    or a command that is defined within the container.

    The list of internal commands changes depending on what softwares are installed within
    the container image. Command internal commands are python, cmake, make, root, and rootbrowse.

  EXTERNAL COMMANDS:
    help    : Print this help message and exit
    config  : Print the current configuration of the container
    list    : List the tag options
    clean   : Reset dbgen computing environment
    cache   : Change the directory in which image layers are stored
    use     : Set image tag to use to run container
    run     : Run the event library generation
    source  : Run the commands in the provided file through dbgen

  EXAMPLES:
    An outline of commands to run in order to generate an event library is.
      dbgen use latest
      dbgen dest /my/output/directory/
      dbgen work /big/scratch/dir/
      dbgen run --aprime 1.0

    dbgen help
    dbgen list 
    dbgen clean container
    dbgen config
    dbgen use v3.0
HELP
  return 0
}

####################################################################################################
# dbgen
#   The root command for users interacting with the dbgen container environment.
#   This function is really just focused on parsing CLI and going to the
#   corresponding subcommand.
#
#   There are lots of subcommands, go to those functions to learn the detail
#   about them.
####################################################################################################
dbgen() {
  # divide commands by outside/inside container and separate by number of arguments
  case $1 in
    # zero arguments
    help|config)
      __dbgen_$1
      return 0
      ;;
    # one argument
    clean|dest|work|source|use|cache)
      if [[ $# -ne 2 ]]; then
        __dbgen_${1}_help
        echo "ERROR: dbgen ${1} requires one argument."
        return 1
      elif [[ "$2" == "help" ]]; then
        # subcommand help
        __dbgen_${1}_help
        return 0
      fi
      # outside container
      __dbgen_$1 ${@:2}
      return $?
      ;;
    # any number of arguments
    list|run)
      if [[ "$2" == "help" ]]; then
        __dbgen_${1}_help
        return 0
      fi
      __dbgen_${1} ${@:2}
      return $?
      ;;
    *)
      __dbgen_help
      return 0
      ;;
  esac
}

####################################################################################################
# DONE WITH NECESSARY PARTS
#   Everything below here is icing on the usability cake.
####################################################################################################

####################################################################################################
# Bash Tab Completion
#   This next section is focused on setting up the infrastucture for smart
#   tab completion with the dbgen command and its sub-commands.
####################################################################################################

####################################################################################################
# __dbgen_complete_directory
#   Some of our sub-commands take a directory as input.
#   In these cases, we can pretend to cd and use bash's internal
#   tab-complete functions.
#   
#   All this requires is for us to shift the COMP_WORDS array one to
#   the left so that the bash internal tab-complete functions don't
#   get distracted by our base command 'dbgen' at the front.
#
#   We could allow for the shift to be more than one if there is a deeper
#   tree of commands that need to be allowed in the future.
####################################################################################################
__dbgen_complete_directory() {
  local _num_words="1"
  COMP_WORDS=(${COMP_WORDS[@]:_num_words})
  COMP_CWORD=$((COMP_CWORD - _num_words))
  _cd
}

####################################################################################################
# __dbgen_complete_bash_default
#   Restore the default tab-completion in bash that uses the readline function
#   Bash default tab completion just looks for filenames
####################################################################################################
__dbgen_complete_bash_default() {
  compopt -o default
  COMPREPLY=()
}

####################################################################################################
# __dbgen_dont_complete
#   Don't tab complete or suggest anything if user <tab>s
####################################################################################################
__dbgen_dont_complete() {
  COMPREPLY=()
}

####################################################################################################
# Modify the list of completion options on the command line
#   Helpful discussion of this procedure from a blog post
#   https://iridakos.com/programming/2018/03/01/bash-programmable-completion-tutorial
#
#   Helpful Stackoverflow answer
#   https://stackoverflow.com/a/19062943
#
#   COMP_WORDS - bash array of space-separated command line inputs including base command
#   COMP_CWORD - index of current word in argument list
#   COMPREPLY  - options available to user, if only one, auto completed
####################################################################################################
__dbgen_complete() {
  # disable readline filename completion
  compopt +o default

  local curr_word="${COMP_WORDS[$COMP_CWORD]}"

  if [[ "$COMP_CWORD" = "1" ]]; then
    # tab completing a main argument
    COMPREPLY=($(compgen -W "help list clean config cache use run source dest work" "$curr_word"))
  elif [[ "$COMP_CWORD" = "2" ]]; then
    # tab complete a sub-argument,
    #   depends on the main argument
    case "${COMP_WORDS[1]}" in
      config|help|list)
        # no more arguments or can't tab-complete efficiently
        __dbgen_dont_complete
        ;;
      clean)
        # arguments from special set
        COMPREPLY=($(compgen -W "all container env" "$curr_word"))
        ;;
      dest|work|cache)
        #directories only after these commands
        __dbgen_complete_directory
        ;;
      *)
        # files like normal tab complete after everything else
        __dbgen_complete_bash_default
        ;;
    esac
  else
    # three or more arguments
    #   check base argument to see if we should continue
    case "${COMP_WORDS[1]}" in
      list|cache|clean|config|help|use|mount|source)
        # these commands shouldn't have tab complete for the third argument 
        #   (or shouldn't have the third argument at all)
        __dbgen_dont_complete
        ;;
      run)
        # TODO make better
        __dbgen_dont_complete
        ;;
      *)
        # everything else has bash default (filenames)
        __dbgen_complete_bash_default
        ;;
    esac
  fi
}

# Tell bash the tab-complete options for our main function dbgen
complete -F __dbgen_complete dbgen

####################################################################################################
# If the default environment file exists, source it.
# Otherwise, trust that the user knows what they are doing.
####################################################################################################

if [[ -f $HOME/.dbgenrc ]]; then
  dbgen source $HOME/.dbgenrc
fi
