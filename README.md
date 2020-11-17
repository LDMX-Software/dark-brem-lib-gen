
# Dark Brem Event Generation using MadGraph and Docker

### docker
This directory contains the actual build context for a docker image that can run the necessary MadGraph event generation script.
Currently, the MadGraph event generation can handle the following variables.

- Number of Events to Generate
- Mass of A' in GeV
- Incident Electron Beam Energy in GeV
- Run Number (used as random number seed) 

The corresponding DockerHub repository for this image is [tomeichlersmith/mg-dark-brem](https://hub.docker.com/repository/docker/tomeichlersmith/mg-dark-brem).

### libGen.py
This script generates a library to be used with the custom dark brem process written in LDMX-Software/SimCore.

### mg-env.sh
This is a bash script that sets up a helpful working environment for using the container built using the above context.
