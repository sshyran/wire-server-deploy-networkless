FROM quay.io/wire/zauth

RUN apk add --no-cache \
    ca-certificates \
    openssl \
    openssh \
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
    python2-dev \
    gnupg \
    coreutils \
    jq \
    bind-tools \
    gcc \
    musl-dev \
    postgresql-dev \
    neovim \
    the_silver_searcher \
    sshpass \
    rsync

COPY . /src

RUN cd /src && make clone wire-server-deploy

WORKDIR /mnt

ENTRYPOINT /bin/bash
