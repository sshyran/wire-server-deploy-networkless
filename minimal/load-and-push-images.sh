#!/usr/bin/env bash

set -ueo pipefail


registry="${1:-127.0.0.1:5000}"


DIR="$( cd "$(dirname "$0")" ; pwd -P )"



# NOTE: the import logic expects the following file name convention:
#       REGISTRY_FQDN+IMAGE_REPOSITORY_AND_NAME++IMAGE_TAG.tar.bz2


for imageArchiveFilePath in "${DIR}"/images/*.tar.bz2; do

    imageArchiveFile="${imageArchiveFilePath##*/}"
    imageFileName="${imageArchiveFile%%.tar*}"

    sanitizedImageRegistryAndName="${imageFileName%++*}"
    imageRegistryAndName="${sanitizedImageRegistryAndName//+//}"
    imageName="${imageRegistryAndName#*/}"
    tag="${imageFileName##*++}"

    # NOTE: only upload images that are referred to in the manifest / helm charts
    if ! grep --quiet "${imageRegistryAndName}:${tag}" "${DIR}/images.manifest"; then
        continue;
    fi

    # NOTE: any registry configured in `registry-mirrors` only represents a mirror of the docker's
    #       default registry (registry-1.docker.io), which is why any image name that is not prefixed
    #       with a repository has to be prepended with docker's default repository ('library'). Bear
    #       in mind, that is requires all image references in every chart has to be normalized to follow
    #       this behaviour
    if [ "${imageName#*/}" = "${imageName}" ]; then
        imageName="library/${imageName}"
    fi

    echo " [INFO] loading ${imageArchiveFilePath} into cache"
    returnMessage=$( bzip2 --decompress --stdout "${imageArchiveFilePath}" | docker image load )
    loadedTagName=$( echo "${returnMessage}" | awk -F' ' '{ print $3 }' )

    echo " [INFO] tagging ${loadedTagName} with ${registry}/${imageName}:${tag}"
    docker tag "${loadedTagName}" "${registry}/${imageName}:${tag}"

    docker push "${registry}/${imageName}:${tag}"

    docker image remove \
       "${registry}/${imageName}:${tag}" \
       "${loadedTagName}"

done
