FROM debian:bullseye-backports AS builder

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV DEBIAN_FRONTEND=noninteractive

RUN set -xe; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libssl-dev \
    libz-dev \
    tcl \
    ;

# belabox patched srt
#
ARG BELABOX_SRT_VERSION=master
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/BELABOX/srt.git /build/srt; \
    cd /build/srt; \
    git checkout $BELABOX_SRT_VERSION; \
    ./configure --prefix=/usr/local; \
    make -j4; \
    make install; \
    ldconfig;

# belabox srtla
#
ARG SRTLA_VERSION=main
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/BELABOX/srtla.git /build/srtla; \
    cd /build/srtla; \
    git checkout $SRTLA_VERSION; \
    make -j4;

RUN cp /build/srtla/srtla_rec /build/srtla/srtla_send /usr/local/bin

# srt-live-server
# Notes
# - adjusted LD_LIBRARY_PATH to include the patched srt lib
# - SRTLA patch applied from https://github.com/b3ck/sls-b3ck-edit/commit/c8ba19289a583d964dc5e54c746e2b24499226f5
# - upstream patch for logging on arm
COPY patches/sls-SRTLA.patch \
    patches/sls-version.patch \
    patches/480f73dd17320666944d3864863382ba63694046.patch /tmp/

ARG SRT_LIVE_SERVER_VERSION=master
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/IRLDeck/srt-live-server.git /build/srt-live-server; \
    cd /build/srt-live-server; \
    git checkout $SRT_LIVE_SERVER_VERSION; \
    patch -p1 < /tmp/sls-SRTLA.patch; \
    patch -p1 < /tmp/480f73dd17320666944d3864863382ba63694046.patch; \
    LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH make -j4; \
    cp bin/* /usr/local/bin;


# runtime container with NOALBS
#
FROM debian:bullseye-backports

RUN set -xe; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    lsof \
    nodejs \
    npm \
    procps \
    supervisor \
    ;

COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/include /usr/local/include
COPY --from=builder /usr/local/bin /usr/local/bin

COPY files/sls.conf /etc/sls/sls.conf
COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY files/logprefix /usr/local/bin/logprefix

RUN set -xe; \
    ldconfig; \
    chmod 755 /usr/local/bin/logprefix;

ARG NOALBS_VERSION=v1.9.5
RUN set -xe; \
    git clone https://github.com/715209/nginx-obs-automatic-low-bitrate-switching /app; \
    cd /app; \
    git checkout $NOALBS_VERSION; \
    npm install fast-fuzzy node-fetch node-media-server obs-websocket-js signale string-template ws xml2js;

EXPOSE 5000/udp 8181/tcp 8282/udp

CMD ["/usr/bin/supervisord"]
