#
#
#

FROM arm32v7/debian:buster

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

ARG GOLANG_VERSION="1.14.2"
ARG GOLANG_SHA256="eb4550ba741506c2a4057ea4d3a5ad7ed5a887de67c7232f1e4795464361c83c"

ARG WALG_VERSION="v0.2.16-2"

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
    && tar -C /usr/local -xzf /tmp/go${GOLANG_VERSION}.linux-armv6l.tar.gz

# package deps
RUN apt-get -y install postgresql-server-dev-11 liblzo2-dev libsodium-dev

ENV PATH="/usr/local/go/bin:${PATH}"

# package build
RUN cd /tmp \ 
    && git clone https://github.com/NixM0nk3y/wal-g.git \
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
