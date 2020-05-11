#
#
#

FROM arm32v7/debian:buster

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

ARG GOLANG_VERSION="1.14.2"
ARG GOLANG_SHA256="eb4550ba741506c2a4057ea4d3a5ad7ed5a887de67c7232f1e4795464361c83c"

ARG WALG_VERSION="v0.2.16"

# basic build infra
RUN apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y install curl build-essential cmake sudo wget git-core autoconf automake pkg-config quilt \
    && apt-get -y install ruby ruby-dev rubygems \
    && gem install --no-document fpm

RUN cd /tmp \
    && echo "==> Downloading Golang..." \
    && curl -fSL  https://dl.google.com/go/go${GOLANG_VERSION}.linux-armv6l.tar.gz -o go${GOLANG_VERSION}.linux-armv6l.tar.gz \
    && sha256sum go${GOLANG_VERSION}.linux-armv6l.tar.gz \
    && echo "${GOLANG_SHA256}  go${GOLANG_VERSION}.linux-armv6l.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go${GOLANG_VERSION}.linux-armv6l.tar.gz \

# package deps
RUN apt-get -y install postgresql-server-dev-11 liblzo2-dev libsodium-dev

# package build
RUN /usr/local/go/bin/go -v get github.com/wal-g/wal-g 
    && cd ~/src/github.com/wal-g/wal-g \
    && git checkout ${TIMESCALEDB_VERSION} \
    && export USE_LIBSODIUM=1 \
    $$ export USE_LZO=1 \
    && make install \
    && make deps \
    && make pg_build

# package install

STOPSIGNAL SIGTERM
