#!/bin/bash

export LANG=C #silences warning form perl

db-lib-gen-help() {
cat <<\HELP
  MadGraph Dark Brem Event Library Generation.
  This scripts assumes that it is being run inside of the tomeichlersmith/madgraph container.
    Usage: db-lib-gen [-h,--help] [-v,--verbose] [-o,--out out_dir] 
                      [--max-energy M] [--min-energy m] [--max-rel-step s]
                      [-A,--apmass apmass] [-r,--run run]
                      [-N,--nevents N] [-M,--maxrecoil max_energy]
      -h,--help      : Print this help message.
      -v,--verbose   : Print messages from this script and MG to the terminal screen.
      -o,--out       : out_dir is the output directory for logging and lhe.
                       Default: present working directory
      --max-energy   : M is the maximum energy of the incident electron beam in GeV.
                       Default: 4.0
      --min-energy   : M is the minimum energy of the incident electron beam in GeV.
                       Default: 2.0
      --max-rel-step : s is the maximum relative step size between sampling points in library
                       Default: 0.1 (i.e. 10%)
      -A,--apmass    : apmass is the mass of the A' in GeV.
                       Default: 0.01
      -r,--run       : run is the run number which acts as the random numbe seed.
                       Default: 3000
      -N,--nevents   : N is the number of events to attempt to generate.
                       Default: 20000
      -M,--maxrecoil : max_energy is the maximum energy in GeV that the recoil electron is allowed to have.
                       Default: 1d5
HELP
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

# Our special copying function,
#   sometimes jobs interrupt the copying mid-way through
#   (don't know why this happens)
#   but this means we need to check that the copied file
#   matches the actually generated file. This is done
#   using 'cmp -s' which does a bit-wise comparison and
#   returns a failure status upon the first mis-match.
#   
#   Sometimes (usually for larger files like ours),
#   the kernel decides to put the file into a buffer
#   and have cp return success. This is done because
#   the computer can have the copy continue on in the
#   background without interfering with the user.
#   In our case, this sometimes causes a failure because
#   we attempt to compare the copied file (which is only
#   partial copied) to the original. To solve this
#   niche issue, we can simply add the 'sync' command
#   which tells the terminal to wait for these write
#   buffers to finish before moving on.
#
#   We return a success-status of 0 if we cp and cmp.
#   Otherwise, we make sure any partially-copied files
#   are removed from the destination directory and try again
#   until the input number of tries are attempted.
#   If we get through all tries without return success,
#   then we return a failure status of 1.
#
#   Arguments
#     1 - Time in seconds to sleep between tries
#     2 - Number of tries to attempt before giving up
#     3 - source file to copy
#     4 - destination directory to put copy in
copy-and-check() {
  local _sleep_between_tries="$1"
  local _num_tries="$2"
  local _source="$3"
  local _dest_dir="$4"
  for try in $(seq $_num_tries); do
    if cp -t $_dest_dir $_source; then
      sync #wait for large files to actually leave buffer
      if cmp -s $_source $_dest_dir/$_source; then
        #SUCCESS!
        return 0;
      else
        #Interrupted during copying
        #   delete half-copied file
        rm $_dest_dir/$_source
      fi
    fi
    sleep $_sleep_between_tries
  done
  # make it here if we didn't have a success
  return 1
}


###############################################################################
# Save inputs to helpfully named variables
_out_dir=$(pwd)
_apmass="0.01"
_min_energy="2.0"
_max_energy="4.0"
_max_rel_step="0.1"
_run="3000"
_max_recoil_e="1d5"
_nevents="20000"
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
    --max-energy)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 101
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _max_energy="$2"
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 102
      fi
      ;;
    --min-energy)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 101
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _min_energy="$2"
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 102
      fi
      ;;
    --max-rel-step)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 101
      elif [[ $2 =~ ^[.0-9]+$ ]]
      then
        _max_rel_step="$2"
        shift
        shift
      else
        db-lib-gen-requires-num-arg $option
        exit 102
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
    --target)
      if [[ -z "$2" || "$2" =~ "-".* ]]
      then
        db-lib-gen-requires-arg $option
        exit 108
      else
        _target=$2
        shift
        shift
      fi
      ;;
    *)
      db-lib-gen-fatal-error "'$option' is not a valid option."
      exit 110
      ;;
  esac
done

# Determine target parameters from name
_target_mass=noop
_target_A=noop
_target_Z=noop
if [[ ${_target} == "tungsten" ]]; then
  _target_mass=171.3
  _target_A=184.0
  _target_Z=74.0
elif [[ ${_target} == "silicon" ]]; then
  _target_mass=26.15
  _target_A=28.085
  _target_Z=14.0
else
  db-lib-gen-fatal-error "'${_target}' target material not recognized."
  exit 110
fi

###############################################################################
# Define helpful variables
_library_name=electron_tungsten_MaxE_${_max_energy}_MinE_${_min_energy}_RelEStep_${_max_rel_step}_UndecayedAP_mA_${_apmass}_run_$_run

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

# Target properties
_line_=$_target_mass" = ebeam2 ! stationary target energy in GeV"
sed -in "s/.*ebeam2.*/$_line_/" Cards/run_card.dat
_line_=$_target_mass" = mbeam2 ! stationary target mass in GeV"
sed -in "s/.*mbeam2.*/$_line_/" Cards/run_card.dat
_line_="       623 $_target_mass #HPMASS (target nuceleus)"
sed -in "s/.*HPMASS.*/$_line_/" Cards/param_card.dat
_line_="        2    $_target_Z_ #Znuc, nuclear charge"
sed -in "s/.*Znuc.*/$_line_/" Cards/param_card.dat
_line="        Anuc = $_target_A_"
sed -in "s/.*Anuc = /$_line_/" Source/MODEL/couplings.f

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

# calculate number of sampling points in library
_num_energies=$(python3 -c "from math import log10, ceil; print(ceil(log10(${_min_energy}/${_max_energy})/log10(1-${_max_rel_step})))")
# loop over entries in library sequentially
for ie in $(seq ${_num_energies})
do
  energy=$(python3 -c "print(${_max_energy} * (1. - ${_max_rel_step})**(${ie}-1))")

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

# check if output directory exists
#   we wait until here because sometimes
#   hdfs is connected when we start the job
#   but isn't connected at the end
if [[ ! -d $_out_dir ]]; then
  echo "Output directory '$_out_dir' doesn't exist!"
  exit 115
fi

# copy over each output file, checking to make sure it worked
if ! copy-and-check 30 10 ${_library_name}.tar.gz ${_out_dir} 
then 
  db-lib-gen-fatal-error "Could not copy library '${_library_name}.tar.gz' to '${_out_dir}'."
  exit 116
fi

###############################################################################
# Clean-Up, only need to worry about this if running with singularity
if db-lib-gen-in-singularity
then
  db-lib-gen-log "Cleaning up '$_new_working_dir'."
  rm -r $_new_working_dir/*
fi

