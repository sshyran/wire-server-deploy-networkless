FROM alpine:3.9

RUN apk add --no-cache \
    ca-certificates \
    openssl \
    libsodium \
    make \
    bash \
    linux-headers \
    alpine-sdk \
    xz \
    sed \
    ncurses \
    git \
    curl \
    tar \
    wget \
    python \
    py2-pip \
    python2-dev \
    gnupg \
    coreutils \
    jq \
    bind-tools \
    gcc \
    musl-dev \
    postgresql-dev

RUN pip install poetry

COPY . /src

WORKDIR /src

RUN make wire-server-deploy

