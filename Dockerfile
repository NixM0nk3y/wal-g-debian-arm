#
#
#

FROM debian:buster

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

ARG GOLANG_VERSION="1.17.6"
ARG GOLANG_SHA256="82c1a033cce9bc1b47073fd6285233133040f0378439f3c4659fe77cc534622a"

ARG WALG_VERSION="v1.1"

# basic build infra
RUN apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y install curl build-essential cmake sudo wget git-core autoconf automake pkg-config quilt \
    && apt-get -y install ruby ruby-dev rubygems \
    && gem install --no-document fpm

RUN cd /tmp \
    && echo "==> Downloading Golang..." \
    && curl -fSL  https://go.dev/dl/go${GOLANG_VERSION}.linux-arm64.tar.gz -o go${GOLANG_VERSION}.linux-arm64.tar.gz \
    && sha256sum go${GOLANG_VERSION}.linux-arm64.tar.gz \
    && echo "${GOLANG_SHA256}  go${GOLANG_VERSION}.linux-arm64.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go${GOLANG_VERSION}.linux-arm64.tar.gz

# package deps
RUN apt-get -y install postgresql-server-dev-11 liblzo2-dev libsodium-dev

ENV PATH="/usr/local/go/bin:${PATH}"

# package build
RUN cd /tmp \ 
    && git clone https://github.com/wal-g/wal-g.git \
    && cd wal-g \
    && git checkout ${WALG_VERSION} \
    && export USE_LIBSODIUM=true \
    && export USE_LZO=true \
    && make install \
    && make deps \
    && make pg_build

# package install
RUN cd /tmp/wal-g \
    && install -D -m 0755 main/pg/wal-g /install/usr/local/bin/wal-g \
    && fpm -s dir -t deb -C /install --name wal-g-postgresql --version $(echo ${WALG_VERSION}| sed -e s/v//) --iteration 2 \
       --description "Archival and Restoration for Postgres"

STOPSIGNAL SIGTERM
