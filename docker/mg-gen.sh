#!/bin/bash

export LANG=C #silences warning form perl
export _default_mg_gen_out_dir=$(pwd)
export _default_mg_gen_apmass="0.01"
export _default_mg_gen_energy="4.0"
export _default_mg_gen_run="3000"
export _default_mg_gen_nevents="20000"

mg-gen-help() {
  echo "MadGraph Dark Brem Event Generation."
  echo "This scripts assumes that it is being run inside of the tomeichlersmith/madgraph container."
  echo "  Usage: mg-gen [-h,--help] [-v,--verbose] [-l,--log] [-o,--out out_dir] "
  echo "                [-A,--apmass apmass] [-E,--energy energy] [-r,--run run] [-N,--nevents N]"
  echo "    -h,--help    : Print this help message."
  echo "    -v,--verbose : Print messages from this script and MG to the terminal screen."
  echo "    -o,--out     : out_dir is the output directory for logging and lhe."
  echo "                   Default: $_default_mg_gen_out_dir"
  echo "    -A,--apmass  : apmass is the mass of the A' in GeV."
  echo "                   Default: $_default_mg_gen_apmass"
  echo "    -E,--energy  : energy is the energy of the incident electron beam in GeV."
  echo "                   Default: $_default_mg_gen_energy"
  echo "    -r,--run     : run is the run number which acts as the random numbe seed."
  echo "                   Default: $_default_mg_gen_run"
  echo "    -N,--nevents : N is the number of events to attempt to generate."
  echo "                   Default: $_default_mg_gen_nevents"
}

mg-gen-fatal-error() {
  echo "ERROR: $@"
  mg-gen-help
}

mg-gen-requires-arg() {
  mg-gen-fatal-error "The '$1' flag requires an argument after it!"
}

mg-gen-requires-num-arg() {
  mg-gen-fatal-error "The '$1' flag requires a numerical argument."
}

mg-gen-log() {
  [[ "$_verbose" == *"ON"* ]] && { echo "[ mg-gen ] : $@"; }
}

mg-gen-in-singularity() {
  [[ -f "/singularity" ]] && return 0;
  return 1;
}

###############################################################################
# Save inputs to helpfully named variables
_out_dir=$_default_mg_gen_out_dir
_apmass=$_default_mg_gen_apmass
_energy=$_default_mg_gen_energy
_run=$_default_mg_gen_run
_nevents=$_default_mg_gen_nevents
_verbose="OFF"

while [[ $# -gt 0 ]]
do
  option="$1"
  case "$option" in
    -h|--help)
      mg-gen-help
      exit 0
      ;;
    -v|--verbose)
      _verbose="ON"
      shift
      ;;
    -o|--out)
      if [[ -z "$2" ]]
      then
        mg-gen-requires-arg $option
        exit 1
      fi
      _out_dir="$2"
      shift
      shift
      ;;
    -A|--apmass)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        mg-gen-requires-arg $option
        exit 2
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _apmass="$2"
        shift
        shift
      else
        mg-gen-requires-num-arg $option
        exit 3
      fi
      ;;
    -E|--energy)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        mg-gen-requires-arg $option
        exit 4
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _energy=$2
        shift
        shift
      else
        mg-gen-requires-num-arg $option
        exit 5
      fi
      ;;
    -r|--run)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        mg-gen-requires-arg $option
        exit 6
      elif [[ $2 =~ ^[0-9]+$ ]]
      then
        _run=$2
        shift
        shift
      else
        mg-gen-requires-num-arg $option
        exit 7
      fi
      ;;
    -N|--nevents)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        mg-gen-requires-arg $option
        exit 8
      elif [[ $2 =~ ^[0-9]+$ ]]
      then
        _nevents=$2
        shift
        shift
      else
        mg-gen-requires-num-arg $option
        exit 9
      fi
      ;;
    *)
      mg-gen-fatal-error "'$option' is not a valid option."
      exit 127
      ;;
  esac
done

###############################################################################
# Define helpful variables
_library_name=LDMX_W_UndecayedAP_mA_${_apmass}_run_$_run
_lhe_dir=$_out_dir/$_library_name
_log_dir=$_out_dir/log/$_library_name #location of log output
_prefix=${_library_name}_IncidentE_${_energy}

if mg-gen-in-singularity()
then
  # we are in singularity and need to move completely to /tmp/ so we have enough space
  # assumes a sizeable /scratch/ directory has been mounted to the container at /working_dir/
  _new_working_dir=/working_dir/$_prefix
  mg-gen-log "Moving working directory to '$_new_working_dir'."
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

# energy of incoming beam in GeV
_line_=$_energy" = ebeam1  ! beam 1 energy in GeV"
sed -in "s/.*ebeam1.*/$_line_/" Cards/run_card.dat

# energy of stationary target in GeV
_line_="171.3 = ebeam2 ! beam 2 energy in GeV"
sed -in "s/.*ebeam2.*/$_line_/" Cards/run_card.dat

# mass of stationary target in GeV (same as energy because it is stationary)
_line_="171.3 = mbeam2 ! beam 2 energy in GeV"
sed -in "s/.*mbeam2.*/$_line_/" Cards/run_card.dat

# definition of stationary target particle and its mass (tungsten)
_line_="623 171.3 #HPMASS"
sed -in "s/623.*# HPMASS (tungsten)/$_line_/" Cards/param_card.dat

_log=$PWD/$_prefix.log
touch $_log

###############################################################################
# Actually run MadGraph and generate events
#   First Arg  : 0 for generating events serially (1 for in parallel)
#   Second Arg : Prefix to attach to output events package
mg-gen-log "Starting job with $_apmass GeV A', $_energy GeV beam, run number $_run, and $_nevents events."
if [[ $_verbose == *"ON"* ]]
then
  ./bin/generate_events 0 $_prefix 
else
  ./bin/generate_events 0 $_prefix &> /dev/null
fi

###############################################################################
# Copy over generated events to output directory
mg-gen-log "Copying generated events to '$_lhe_dir'."
mkdir -p $_lhe_dir 
mv Events/${_prefix}_unweighted_events.lhe.gz $_lhe_dir
cd $_lhe_dir
gunzip -f ${_prefix}_unweighted_events.lhe.gz #unpack into an LHE file

###############################################################################
# Clean-Up, only need to worry about this if running with singularity
mg-gen-in-singularity() && { mg-gen-log "Cleaning up '$_new_working_dir'."; rm -r $_new_working_dir }

