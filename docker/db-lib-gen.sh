#!/bin/bash

export LANG=C #silences warning form perl
export _default_db_lib_gen_out_dir=$(pwd)
export _default_db_lib_gen_apmass="0.01"
export _default_db_lib_gen_energies="4.0"
export _default_db_lib_gen_run="3000"
export _default_db_lib_gen_nevents="20000"
export _default_db_lib_gen_max_recoil_e="100.0"

db-lib-gen-help() {
  echo "MadGraph Dark Brem Event Library Generation."
  echo "This scripts assumes that it is being run inside of the tomeichlersmith/madgraph container."
  echo "  Usage: db-lib-gen [-h,--help] [-v,--verbose] [-o,--out out_dir] "
  echo "                    [-E,--energy energy0 [energy1 energy2 ...]] "
  echo "                    [-A,--apmass apmass] [-r,--run run]"
  echo "                    [-N,--nevents N] [-M,--maxrecoil max_energy]"
  echo "    -h,--help    : Print this help message."
  echo "    -v,--verbose : Print messages from this script and MG to the terminal screen."
  echo "    -o,--out     : out_dir is the output directory for logging and lhe."
  echo "                   Default: $_default_db_lib_gen_out_dir"
  echo "    -E,--energy  : energy{0..} is the energy of the incident electron beam in GeV."
  echo "                   Default: $_default_db_lib_gen_energies"
  echo "    -A,--apmass  : apmass is the mass of the A' in GeV."
  echo "                   Default: $_default_db_lib_gen_apmass"
  echo "    -r,--run     : run is the run number which acts as the random numbe seed."
  echo "                   Default: $_default_db_lib_gen_run"
  echo "    -N,--nevents : N is the number of events to attempt to generate."
  echo "                   Default: $_default_db_lib_gen_nevents"
  echo "    -M,--maxrecoil: max_energy is the maximum energy in GeV that the recoil electron is allowed to have."
  echo "                   Default: $_default_db_lib_gen_max_recoil_e"
}

db-lib-gen-fatal-error() {
  echo "ERROR [ db-lib-gen ] : $@"
}

db-lib-gen-requires-arg() {
  db-lib-gen-fatal-error "The '$1' flag requires an argument after it!"
}

db-lib-gen-requires-num-arg() {
  db-lib-gen-fatal-error "The '$1' flag requires a numerical argument."
}

db-lib-gen-log() {
  if $_verbose
  then
    echo "[ db-lib-gen ] : $@"
  fi
  if [[ ! -z "$_log" ]]
  then
    echo "$@" >> $_log
  fi
}

db-lib-gen-in-singularity() {
  [[ -f "/singularity" ]] && return 0;
  return 1;
}

###############################################################################
# Save inputs to helpfully named variables
_out_dir=$_default_db_lib_gen_out_dir
_apmass=$_default_db_lib_gen_apmass
_energies=$_default_db_lib_gen_energies
_run=$_default_db_lib_gen_run
_max_recoil_e=$_default_db_lib_gen_max_recoil_e
_nevents=$_default_db_lib_gen_nevents
_verbose=false

while [[ $# -gt 0 ]]
do
  option="$1"
  case "$option" in
    -h|--help)
      db-lib-gen-help
      exit 0
      ;;
    -v|--verbose)
      _verbose=true
      shift
      ;;
    -o|--out)
      if [[ -z "$2" ]]
      then
        db-lib-gen-requires-arg $option
        exit 100
      fi
      _out_dir="$2"
      shift
      shift
      ;;
    -A|--apmass)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 101
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _apmass="$2"
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 102
      fi
      ;;
    -E|--energy)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 103
      else
        shift #get past option flag
        _energies=""
        while [[ "$1" =~ ^[.0-9]+$ ]]
        do
          _energies="${_energies}$1 "
          shift
        done
      fi
      ;;
    -r|--run)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 104
      elif [[ $2 =~ ^[0-9]+$ ]]
      then
        _run=$2
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 105
      fi
      ;;
    -N|--nevents)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 106
      elif [[ $2 =~ ^[0-9]+$ ]]
      then
        _nevents=$2
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 107
      fi
      ;;
    -M|--maxrecoil)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 108
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _max_recoil_e=$2
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 109
      fi
      ;;
    *)
      db-lib-gen-fatal-error "'$option' is not a valid option."
      exit 110
      ;;
  esac
done

if [[ -z "$_energies" ]]
then
  db-lib-gen-requires-arg "-E, --energy"
  exit 111
fi

###############################################################################
# Define helpful variables
_library_name=LDMX_W_UndecayedAP_mA_${_apmass}_run_$_run

if db-lib-gen-in-singularity
then
  # we are in singularity and need to move completely to /tmp/ so we have enough space
  # assumes a sizeable /scratch/ directory has been mounted to the container at /working_dir/
  _new_working_dir=/working_dir/$_library_name
  db-lib-gen-log "Moving working directory to '$_new_working_dir'."
  mkdir -p $_new_working_dir
  cp -r /madgraph/ $_new_working_dir
  cd $_new_working_dir/madgraph
fi
  
_library_dir=$PWD/$_library_name
_log=$_library_dir/GenerationLog_$_library_name.log
mkdir -p $_library_dir
touch $_log

###############################################################################
# Several Substitutes need to be made to the parameter and running cards
#   These are done here using sed and temp variable _line_

# Put in the A' mass
_line_=622" "$_apmass" ""# APMASS"
sed -in "s/622.*# APMASS/$_line_/" Cards/param_card.dat

# Number of events to generate
_line_=$_nevents" = nevents ! Number of unweighted events requested"
sed -in "s/.*nevents.*/$_line_/" Cards/run_card.dat

# random number seed
_line_=$_run" = iseed ! rnd seed (0=assigned automatically=default))"
sed -in "s/.*iseed.*/$_line_/" Cards/run_card.dat

# Maximum recoil energy
_line_=$_max_recoil_e" = efmax ! maximum E for all f's"
sed -in "s/.*efmax.*/$_line_/" Cards/run_card.dat

###############################################################################
# Actually run MadGraph and generate events
#   First Arg  : 0 for generating events serially (1 for in parallel)
#   Second Arg : Prefix to attach to output events package
#   
#   The defininition of 'gen_events' is changed depending on if we are running
#   with high verbosity or not. 
#   Inherited Bash Variables:
#     _prefix : string the MadGraph executable should attach to the events file
#     _log    : full path to the file that the log should be written to
if $_verbose
then
  gen_events() {
    ./bin/generate_events 0 $_prefix | tee -a $_log && return 0
    _mg_error_code=$?
    return 1
  }
else
  gen_events() {
    ./bin/generate_events 0 $_prefix &>> $_log && return 0
    _mg_error_code=$?
    return 1
  }
fi

for energy in $_energies
do
  # define this item in the library with its own name
  _prefix=${_library_name}_IncidentE_${energy}

  # energy of incoming beam in GeV
  _line_=$energy" = ebeam1  ! incident electron energy in GeV"
  sed -in "s/.*ebeam1.*/$_line_/" Cards/run_card.dat
  
  ###############################################################################
  # Run the MadGraph executable and check if it errored out or not
  db-lib-gen-log "Starting job with $_apmass GeV A', $energy GeV beam, run number $_run, and $_nevents events."
  if ! gen_events
  then
    db-lib-gen-fatal-error "MadGraph event generation exited with non-zero error code $_mg_error_code."
    exit 110
  fi
  
  ###############################################################################
  # Copy over generated events to library directory
  db-lib-gen-log "Copying generated events to '$_library_dir'."
  if ! mkdir -p $_library_dir 
  then 
    db-lib-gen-fatal-error "Could not create library directory '$_library_dir'."
    exit 111
  fi
  
  if ! mv Events/${_prefix}_unweighted_events.lhe.gz $_library_dir 
  then
    db-lib-gen-fatal-error "Could not move package of events 'Events/${_prefix}_unweighted_events.lhe.gz'."
    exit 112
  fi

  cd $_library_dir

  if ! gunzip -f ${_prefix}_unweighted_events.lhe.gz
  then
    db-lib-gen-fatal-error "Could not unzip the events package '${_prefix}_unweighted_events.lhe.gz'."
    exit 113
  fi

  cd - &> /dev/null
done

###############################################################################
# Compress LHE files and log into a library
db-lib-gen-log "Compressing and copying '${_library_name}'."
if ! tar czf ${_library_name}.tar.gz ${_library_name}
then 
  db-lib-gen-fatal-error "Could not compress the library '$_library_name' into an archive."
  exit 114
fi

if ! cp ${_library_name}.tar.gz ${_out_dir} 
then 
  db-lib-gen-fatal-error "Could not copy library '${_library_name}.tar.gz' to '${_out_dir}'."
  exit 115
fi

###############################################################################
# Clean-Up, only need to worry about this if running with singularity
if db-lib-gen-in-singularity
then
  db-lib-gen-log "Cleaning up '$_new_working_dir'."
  rm -r $_new_working_dir/*
fi

