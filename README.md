
# Dark Brem Event Generation
This repository stores the build context for a container image which holds a specific instance of MadGraph
designed to generate dark bremsstrahlung events over a range of incident lepton energies. Specifically,
the output of running this container is a "library" of dark brem events which can be used within
[LDMX's simulation infrastructure](https://github.com/LDMX-Software/SimCore).

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

