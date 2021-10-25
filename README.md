
# Dark Brem Event Generation using MadGraph and Docker

## Quick Start
If you aren't developing the container and just wish to use it,
you do not need to clone this entire repository. You can simply download
the environment script and start using it.

```
wget https://raw.githubusercontent.com/tomeichlersmith/dark-brem-lib-gen/main/env.sh
source env.sh
```

### context

<a href="https://github.com/tomeichlersmith/mg-dark-brem/actions" alt="Actions">
    <img src="https://github.com/tomeichlersmith/mg-dark-brem/workflows/Build/badge.svg" />
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

### env.sh
This is a bash script that sets up a helpful working environment for using the container built using the above context.
It defines the following functions for systems with either docker or singularity installed.

- `db-lib-gen` : Alias for the complicated container-running command. Use `db-lib-gen --help` to see the full option detail.
