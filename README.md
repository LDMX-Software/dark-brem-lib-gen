
# Dark Brem Event Generation using MadGraph and Docker

### docker

<a href="https://github.com/tomeichlersmith/mg-dark-brem/actions" alt="Actions">
    <img src="https://github.com/tomeichlersmith/mg-dark-brem/workflows/Build/badge.svg" />
</a>

This directory contains the actual build context for a docker image that can run the necessary [MadGraph](https://cp3.irmp.ucl.ac.be/projects/madgraph/) event generation script.
Currently, the MadGraph event generation can handle the following variables.

- Number of Events to Generate
- Mass of A' in GeV
- Incident Electron Beam Energy in GeV
- Run Number (used as random number seed) 

The corresponding DockerHub repository for this image is [tomeichlersmith/mg-dark-brem](https://hub.docker.com/repository/docker/tomeichlersmith/mg-dark-brem).

### env.sh
This is a bash script that sets up a helpful working environment for using the container built using the above context.
It defines the following functions for systems with either docker or singularity installed.

- `mg-gen` : Alias for the complicated container-running command. Use `mg-gen --help` to see the full option detail.
- `generate-db-lib {run_num}` : Generate a full dark brem vertex library for the input run number. This vertex library iterates over the six main mass points and eight incident electron energies between two and four GeV, generating 20k events for each pair.
