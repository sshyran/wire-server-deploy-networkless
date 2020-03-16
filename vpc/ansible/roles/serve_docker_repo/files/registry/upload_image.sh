#!/usr/bin/env bash

# the registry we are loading content into.
target_registry="localhost:5001"

function mirror() {
    local prefix=${1}${1:+/}  # append '/' if `prefix` is not empty string
    local dest_image=$2
    # if the image being transfered starts with library/, drop library/ when pulling it.
    local source_image=$(echo $2 | sed "s=library/==")
    local source_registry=${3}${3:+/}
    local rmafter=$4

    docker pull $source_registry$prefix$source_image
    docker tag $source_registry$prefix$source_image $target_registry/$dest_image
    docker push $target_registry/$dest_image
    [ -n "$rmafter" ] && docker image remove $target_registry/$dest_image
    [ -n "$rmafter" ] && docker image remove $source_registry$prefix$source_image
}

mirror "$1" "$2" "$3" yes
