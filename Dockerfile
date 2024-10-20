#
#
#

FROM debian:bookworm

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

ARG GOLANG_VERSION="1.23.2"
ARG GOLANG_SHA256="f626cdd92fc21a88b31c1251f419c17782933a42903db87a174ce74eeecc66a9"

ARG WALG_VERSION="v3.0.3"

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
RUN apt-get -y install postgresql-server-dev-15 liblzo2-dev libsodium-dev libbrotli-dev curl cmake

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
    && fpm -s dir -t deb -C /install --name wal-g-postgresql --version $(echo ${WALG_VERSION}| sed -e s/v//) --iteration 3 \
       --description "Archival and Restoration for Postgres"

STOPSIGNAL SIGTERM
