
# Dark Brem Event Generation
This repository stores the build context for a container image which holds a specific instance of MadGraph
designed to generate dark bremsstrahlung events over a range of incident lepton energies. Specifically,
the output of running this container is a "library" of dark brem events which can be used within
[G4DarkBreM](https://github.com/LDMX-Software/G4DarkBreM).

## Quick Start
If you aren't developing the container and just wish to use it,
you do not need to clone this entire repository. You can simply download
the environment script and start running it.

```
wget https://raw.githubusercontent.com/tomeichlersmith/dark-brem-lib-gen/main/env.sh
source env.sh
dbgen use v4.0 # choose version, must be version 4 or newer (older versions used different interface)
dbgen cache /big/cache/dir # choose location for caching image layers
dbgen dest /my/destination # choose output location (default is PWD)
dbgen work /scratch/dir # big (>1GB) scratch directory (default is /tmp)
dbgen run --help # print out runtime options
```

## Usage Manual
This section lists the different command line options with a bit more explanation that what the command line itself has room for.

`--pack` instructs the script to package the directory of generated LHE files into a tar-ball (`.tar.gz` file) after they are all written to the output directory. This can be helpful if the newly-generated library needs to be moved immediately after generation since it is generally easier to move only one file that a directory of files.

`--run` changes the run number for MadGraph which is used as its random seed. This should be changed if multiple libraries with the same parameters wish to be generated for larger signal samples.

`--nevents` sets the number of events _for each_ energy point in the library. Generally, MadGraph (especially MadGraph4) is limited to under 100k events for each random seed that is used and so the default of 20k is a reasonable number.

`--max_energy` sets the highest energy (in GeV) to be put into the reference library.

`--min_energy` sets the minimum energy (in GeV) to be put into the reference library. The default is half of the maximum energy.

`--rel_step` sets the relative step size between different energy sampling points in the library. The default is 0.1 (or 10%) which was determined qualitatively by looking at distributions studying the scaling behavior implemented in G4DarkBreM.

`--max_recoil` sets the maximum energy (in GeV) a recoil lepton is allowed to have. The default is `1d5` (or no maximum in MadGraph4). This has not been studied in any detail and could very easily not be doing what I think it is doing.

`--apmass` sets the mass of the dark photon (in GeV) for MadGraph to use in the dark brem.

`--target` sets the target material(s) to shoot leptons at. If more than one material is provided, then the library will contain all of the configured energy sample points for each of the different materials. The available materials are shown in the help message - other materials can be added once the mass of the nucleus (in GeV), the atomic mass (in amu), and the atomic number are known.

`--lepton` sets the lepton to shoot (either electrons or muons).

`--elastic-ff-only` edits the nuclear form factor equation to only include the elastic part in the dark brem coupling. This was helpful when studying the total cross section but should _not_ be used in any signal simulation sample.

## context

<a href="https://github.com/tomeichlersmith/mg-dark-brem/actions" alt="Actions">
    <img src="https://github.com/tomeichlersmith/dark-brem-lib-gen/workflows/CI/badge.svg" />
</a>

This directory contains the actual build context for a docker image that can run the necessary [MadGraph](https://cp3.irmp.ucl.ac.be/projects/madgraph/) event generation script.
Currently, the MadGraph event generation can handle the following variables.

- Number of Events to Generate
- Mass of A' in GeV
- Target material (from list of options)
- Lepton (muon or electron)
- Maximum and Minimum Incident Beam Energy in GeV
- Relative step between sampling points in library
- Run Number (used as random number seed) 

The corresponding DockerHub repository for this image is [tomeichlersmith/dark-brem-lib-gen](https://hub.docker.com/repository/docker/tomeichlersmith/dark-brem-lib-gen).

## env.sh
This is a bash script that sets up a helpful working environment for using the container built using the above context.
It defines a helpful wrapper for using the image built with this context in singularity or docker.

## analysis
A helpful python module for analyzing the dark brem event libraries separately from ldmx-sw.

# Batch Running
The environment script is able to deduce if it is in a non-interactive environment, 
so it can be used within another script to (for example) use within a batch processing
system. For example, a script I use with [HTCondor](https://htcondor.readthedocs.io/en/latest/) 
is below. The path `/full/path/to/shared/location` is the full path to a filesystem shared
across all worker nodes.

```bash
#!/bin/bash
set -ex
# initialize dbgen environment
source /full/path/to/shared/location/env.sh
# use a pre-built SIF file to avoid overloading DockerHub's pull limit
dbgen use /full/path/to/shared/location/tomeichlersmith_dark-brem-lib-gen_v4.4.sif
# local scratch area
mkdir scratch
dbgen work scratch
# run dbgen with the arguments to this script
dbgen run $@

# condor doesn't scan subdirectories so we should move the LHE files here
#  you could avoid this nonsense with some extra condor config
find \
  -type f \
  -name "*.lhe" \
  -exec mv {} . ';'
```
