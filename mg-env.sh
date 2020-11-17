
export MG_DOCKER_TAG="tomeichlersmith/madgraph:alpha"

alias mg-gen='docker run --rm -it -v $(pwd):$(pwd) -u $(id -u $USER):$(id -g $USER) ${MG_DOCKER_TAG} --out $(pwd)'
