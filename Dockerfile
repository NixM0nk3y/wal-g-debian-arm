# syntax=docker/dockerfile:1
#
# Multi-arch (amd64 + arm64) build of the wal-g-postgresql .deb.
#
# buildx populates TARGETARCH (amd64|arm64); the base image, the Go
# toolchain tarball, and the resulting .deb architecture all follow it.
# Build per-arch with `--load` (see the Makefile), or directly:
#   docker buildx build --platform linux/arm64 --load -t wal-g:arm64 .
#

FROM debian:trixie

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

# Provided automatically by buildx (amd64 | arm64). Default keeps a bare
# `docker build` working on an amd64 host.
ARG TARGETARCH=amd64

ARG GOLANG_VERSION="1.26.3"
# Per-arch checksum for go${GOLANG_VERSION}.linux-${TARGETARCH}.tar.gz.
# Refresh both on a Go bump: https://go.dev/dl/?mode=json&include=all
ARG GOLANG_SHA256_amd64="2b2cfc7148493da5e73981bffbf3353af381d5f93e789c82c79aff64962eb556"
ARG GOLANG_SHA256_arm64="9d89a3ea57d141c2b22d70083f2c8459ba3890f2d9e818e7e933b75614936565"

ARG WALG_VERSION="v3.0.8"

# basic build infra
RUN apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y install curl build-essential cmake sudo wget git-core autoconf automake pkg-config quilt \
    && apt-get -y install ruby ruby-dev rubygems \
    && gem install --no-document fpm

# Go toolchain — arch + pinned checksum selected from TARGETARCH
RUN cd /tmp \
    && case "${TARGETARCH}" in \
         amd64) GOLANG_SHA256="${GOLANG_SHA256_amd64}" ;; \
         arm64) GOLANG_SHA256="${GOLANG_SHA256_arm64}" ;; \
         *) echo "unsupported TARGETARCH='${TARGETARCH}'" >&2; exit 1 ;; \
       esac \
    && echo "==> Downloading Go ${GOLANG_VERSION} for linux-${TARGETARCH}..." \
    && curl -fSL "https://go.dev/dl/go${GOLANG_VERSION}.linux-${TARGETARCH}.tar.gz" -o go.tar.gz \
    && echo "${GOLANG_SHA256}  go.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz

# package deps
RUN apt-get -y install postgresql-server-dev-17 liblzo2-dev libsodium-dev libbrotli-dev cmake

ENV PATH="/usr/local/go/bin:${PATH}"

# package build
RUN cd /tmp \
    && git clone https://github.com/wal-g/wal-g.git \
    && cd wal-g \
    && git checkout ${WALG_VERSION} \
    && export USE_LIBSODIUM=true \
    && export USE_LZO=true \
    && export USE_BROTLI=true \
    && export GOEXPERIMENT=jsonv2 \
    && make install \
    && make deps \
    && make pg_build

# package install — fpm tags the .deb with the target arch (dpkg reports
# the emulated/native container arch, i.e. TARGETARCH)
RUN cd /tmp/wal-g \
    && install -D -m 0755 main/pg/wal-g /install/usr/local/bin/wal-g \
    && fpm -s dir -t deb -C /install --name wal-g-postgresql \
       --version "$(echo ${WALG_VERSION} | sed -e s/v//)" --iteration 4 \
       --architecture "$(dpkg --print-architecture)" \
       --description "Archival and Restoration for Postgres"

STOPSIGNAL SIGTERM
