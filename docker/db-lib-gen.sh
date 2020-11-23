#!/bin/bash

export LANG=C #silences warning form perl
export _default_db_lib_gen_out_dir=$(pwd)
export _default_db_lib_gen_apmass="0.01"
export _default_db_lib_gen_energies="4.0"
export _default_db_lib_gen_run="3000"
export _default_db_lib_gen_nevents="20000"

db-lib-gen-help() {
  echo "MadGraph Dark Brem Event Library Generation."
  echo "This scripts assumes that it is being run inside of the tomeichlersmith/madgraph container."
  echo "  Usage: db-lib-gen [-h,--help] [-v,--verbose] [-l,--log] [-o,--out out_dir] "
  echo "                [-A,--apmass apmass] [-E,--energy energy0 [energy1 energy2 ...]] [-r,--run run] [-N,--nevents N]"
  echo "    -h,--help    : Print this help message."
  echo "    -v,--verbose : Print messages from this script and MG to the terminal screen."
  echo "    -o,--out     : out_dir is the output directory for logging and lhe."
  echo "                   Default: $_default_db_lib_gen_out_dir"
  echo "    -A,--apmass  : apmass is the mass of the A' in GeV."
  echo "                   Default: $_default_db_lib_gen_apmass"
  echo "    -E,--energy  : energy{0..} is the energy of the incident electron beam in GeV."
  echo "                   Default: $_default_db_lib_gen_energies"
  echo "    -r,--run     : run is the run number which acts as the random numbe seed."
  echo "                   Default: $_default_db_lib_gen_run"
  echo "    -N,--nevents : N is the number of events to attempt to generate."
  echo "                   Default: $_default_db_lib_gen_nevents"
}

db-lib-gen-fatal-error() {
  echo "ERROR: $@"
  db-lib-gen-help
}

db-lib-gen-requires-arg() {
  db-lib-gen-fatal-error "The '$1' flag requires an argument after it!"
}

db-lib-gen-requires-num-arg() {
  db-lib-gen-fatal-error "The '$1' flag requires a numerical argument."
}

db-lib-gen-log() {
  [[ "$_verbose" == *"ON"* ]] && { echo "[ db-lib-gen ] : $@"; }
  [[ -z $_log ]] || { echo "$@" >> $_log; }
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
_nevents=$_default_db_lib_gen_nevents
_verbose="OFF"

while [[ $# -gt 0 ]]
do
  option="$1"
  case "$option" in
    -h|--help)
      db-lib-gen-help
      exit 0
      ;;
    -v|--verbose)
      _verbose="ON"
      shift
      ;;
    -o|--out)
      if [[ -z "$2" ]]
      then
        db-lib-gen-requires-arg $option
        exit 1
      fi
      _out_dir="$2"
      shift
      shift
      ;;
    -A|--apmass)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 2
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _apmass="$2"
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 3
      fi
      ;;
    -E|--energy)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 4
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
        exit 6
      elif [[ $2 =~ ^[0-9]+$ ]]
      then
        _run=$2
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 7
      fi
      ;;
    -N|--nevents)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 8
      elif [[ $2 =~ ^[0-9]+$ ]]
      then
        _nevents=$2
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 9
      fi
      ;;
    *)
      db-lib-gen-fatal-error "'$option' is not a valid option."
      exit 127
      ;;
  esac
done

[[ -z "$_energies" ]] && db-lib-gen-requires-arg "-E, --energy"

###############################################################################
# Define helpful variables
_library_name=LDMX_W_UndecayedAP_mA_${_apmass}_run_$_run
_library_dir=$PWD/$_library_name
_log=$_library_dir/GenerationLog_$_library_name.log
mkdir -p $_library_dir
touch $_log

if db-lib-gen-in-singularity
then
  # we are in singularity and need to move completely to /tmp/ so we have enough space
  # assumes a sizeable /scratch/ directory has been mounted to the container at /working_dir/
  _new_working_dir=/working_dir/$_prefix
  db-lib-gen-log "Moving working directory to '$_new_working_dir'."
  mkdir -p $_new_working_dir
  cp -r /madgraph/ $_new_working_dir
  cd $_new_working_dir/madgraph
fi
  
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
#_line_=" 2.0 = efmax ! maximum E for all f's"
#sed -in "s/.*efmax.*/$_line_/" Cards/run_card.dat

# energy of stationary target in GeV
_line_="171.3 = ebeam2 ! beam 2 energy in GeV"
sed -in "s/.*ebeam2.*/$_line_/" Cards/run_card.dat

# mass of stationary target in GeV (same as energy because it is stationary)
_line_="171.3 = mbeam2 ! beam 2 energy in GeV"
sed -in "s/.*mbeam2.*/$_line_/" Cards/run_card.dat

# definition of stationary target particle and its mass (tungsten)
_line_="623 171.3 #HPMASS"
sed -in "s/623.*# HPMASS (tungsten)/$_line_/" Cards/param_card.dat

for energy in $_energies
do
  # define this item in the library with its own name
  _prefix=${_library_name}_IncidentE_${energy}

  # energy of incoming beam in GeV
  _line_=$energy" = ebeam1  ! beam 1 energy in GeV"
  sed -in "s/.*ebeam1.*/$_line_/" Cards/run_card.dat
  
  ###############################################################################
  # Actually run MadGraph and generate events
  #   First Arg  : 0 for generating events serially (1 for in parallel)
  #   Second Arg : Prefix to attach to output events package
  db-lib-gen-log "Starting job with $_apmass GeV A', $energy GeV beam, run number $_run, and $_nevents events."
  if [[ $_verbose == *"ON"* ]]
  then
    ./bin/generate_events 0 $_prefix | tee -a $_log
  else
    ./bin/generate_events 0 $_prefix &> $_log
  fi
  
  ###############################################################################
  # Copy over generated events to library directory
  db-lib-gen-log "Copying generated events to '$_library_dir'."
  mkdir -p $_library_dir 
  mv Events/${_prefix}_unweighted_events.lhe.gz $_library_dir
  cd $_library_dir
  gunzip -f ${_prefix}_unweighted_events.lhe.gz #unpack into an LHE file
  cd - &> /dev/null
done

###############################################################################
# Compress LHE files and log into a library
db-lib-gen-log "Compressing and copying '${_library_name}'."
tar czf ${_library_name}.tar.gz ${_library_name}
cp ${_library_name}.tar.gz ${_out_dir}

###############################################################################
# Clean-Up, only need to worry about this if running with singularity
if db-lib-gen-in-singularity
then
  db-lib-gen-log "Cleaning up '$_new_working_dir'."
  rm -r $_new_working_dir;
fi

