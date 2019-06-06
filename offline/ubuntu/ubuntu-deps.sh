#!/usr/bin/env bash

SUDO="${SUDO:-}" # override with 'export SUDO=sudo' when not in docker

$SUDO apt update
$SUDO apt install -y make python2.7 python-dev python-pip tar dnsutils openssl sed curl git

curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py > get-poetry.py
python get-poetry.py -y
source "$HOME/.poetry/env"

