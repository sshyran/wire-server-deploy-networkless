#!/usr/bin/env bash

registry_name="localhost:5001"

function mirror() {
    local prefix=${1}${1:+/}  # append '/' if `prefix` is not empty string
    local image=$2
    local registry=$3
    local rmafter=$4

    docker pull $registry/$prefix$image
    docker tag $registry/$prefix$image $registry_name/$prefix$image
    docker push $registry_name/$prefix$image
    [ -n "$rmafter" ] && docker image remove $registry_name/$prefix$image
    [ -n "$rmafter" ] && docker image remove $registry/$prefix$image
}

mirror ${1:-''} $2 ${3:-docker.io} yes
