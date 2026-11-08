# syntax=docker/dockerfile:1
# ^ Use the latest stable Dockerfile syntax (BuildKit). Enables COPY --chmod.
#
# Asterisk built from the official source code, in two stages:
#   1. "build":   compiler + development headers. Downloads, verifies and
#                 compiles Asterisk with the bundled pjproject.
#   2. "runtime": only the runtime libraries and the files installed by stage 1.
#                 No compiler, no source code, runs as the unprivileged user "asterisk".

# Debian release used by both stages. Declared before the first FROM, so it is
# only usable in FROM lines.
ARG DEBIAN_RELEASE=trixie

###############################################################################
# Stage 1: build
###############################################################################
FROM debian:${DEBIAN_RELEASE}-slim AS build

# Asterisk version to build. Override with --build-arg ASTERISK_VERSION=x.y.z
# (docker compose passes LAB_ASTERISK_VERSION from .env).
ARG ASTERISK_VERSION=22.11.0
# Stop apt from asking interactive questions. ARG (not ENV) so it does not
# leak into the final image.
ARG DEBIAN_FRONTEND=noninteractive

# Build dependencies. One RUN = one layer, so the apt cache is deleted in the
# same RUN that created it.
#   build-essential, pkg-config  compiler toolchain
#   ca-certificates, curl        HTTPS downloads (Asterisk, pjproject, sounds)
#   bzip2, patch                 unpack and patch the bundled pjproject
#   libedit-dev                  CLI line editing (required)
#   libjansson-dev               JSON, needed by ARI (required)
#   libxml2-dev, libxslt1-dev    XML docs and config parsing (required)
#   libsqlite3-dev               internal AstDB (required)
#   uuid-dev                     unique IDs (required)
#   libssl-dev                   TLS for SIP and HTTPS (week 9)
#   libsrtp2-dev                 SRTP media encryption (week 9)
#   libcurl4-openssl-dev         res_curl / CURL() dialplan function
#   libspeexdsp-dev              resampling, jitter buffer, func_speex
#   unixodbc-dev                 ODBC for CDR/queue_log in a database (week 6)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential pkg-config ca-certificates curl bzip2 patch \
      libedit-dev libjansson-dev libxml2-dev libxslt1-dev libsqlite3-dev \
      uuid-dev libssl-dev libsrtp2-dev libcurl4-openssl-dev libspeexdsp-dev \
      unixodbc-dev \
 && rm -rf /var/lib/apt/lists/*

# Download the release tarball and its official SHA-256 checksum, verify it
# and unpack it. sha256sum -c fails the build if the file is corrupted.
WORKDIR /usr/src
RUN base="https://downloads.asterisk.org/pub/telephony/asterisk/releases" \
 && curl -fsSLO "${base}/asterisk-${ASTERISK_VERSION}.tar.gz" \
 && curl -fsSLO "${base}/asterisk-${ASTERISK_VERSION}.sha256" \
 && sha256sum -c "asterisk-${ASTERISK_VERSION}.sha256" \
 && tar -xzf "asterisk-${ASTERISK_VERSION}.tar.gz" \
 && mv "asterisk-${ASTERISK_VERSION}" asterisk \
 && rm "asterisk-${ASTERISK_VERSION}.tar.gz"

WORKDIR /usr/src/asterisk

# configure: detect libraries and choose install paths.
#   --prefix/--sysconfdir/--localstatedir  standard FHS layout:
#        /usr/sbin/asterisk, /etc/asterisk, /var/lib|log|spool/asterisk
#   --libdir=/usr/lib            Debian path (configure may pick lib64 otherwise)
#   --with-pjproject-bundled     download and build the pjproject version
#        tested with this Asterisk release (the SIP stack used by chan_pjsip)
RUN ./configure \
      --prefix=/usr \
      --sysconfdir=/etc \
      --localstatedir=/var \
      --libdir=/usr/lib \
      --with-pjproject-bundled

# menuselect: choose what gets built and installed (like a kernel menuconfig,
# non-interactive here). Optional modules whose -dev library is not installed
# are skipped automatically.
#   BUILD_NATIVE off   no CPU-specific optimizations: the image must also run
#                      on the CI runner and other machines
#   sounds             only u-law (G.711) prompts, in English and Spanish,
#                      plus u-law music on hold. Avoids transcoding.
RUN make menuselect.makeopts \
 && menuselect/menuselect \
      --disable BUILD_NATIVE \
      --disable-category MENUSELECT_CORE_SOUNDS \
      --disable-category MENUSELECT_MOH \
      --disable-category MENUSELECT_EXTRA_SOUNDS \
      --enable CORE-SOUNDS-EN-ULAW \
      --enable CORE-SOUNDS-ES-ULAW \
      --enable EXTRA-SOUNDS-EN-ULAW \
      --enable MOH-OPSOUND-ULAW \
      menuselect.makeopts

# Compile with all CPU threads, install into a staging directory (DESTDIR)
# instead of / so the runtime stage can copy exactly what was installed.
# No "make samples": our own config comes from the repo.
# strip removes debug symbols (much smaller image; fine for a lab).
RUN make -j"$(nproc)" \
 && make install DESTDIR=/staging \
 && find /staging -type f -name '*.so*' -exec strip --strip-unneeded {} + \
 && strip --strip-unneeded /staging/usr/sbin/asterisk

# On Debian /var/run is a symlink to /run, and COPY cannot copy a directory
# over a symlink. Move what "make install" put in /var/run to /run.
# Separate RUN on purpose: changing it does not invalidate the compile layer.
RUN mkdir -p /staging/run \
 && cp -a /staging/var/run/. /staging/run/ \
 && rm -rf /staging/var/run

###############################################################################
# Stage 2: runtime
###############################################################################
FROM debian:${DEBIAN_RELEASE}-slim AS runtime

# ARGs do not cross stages: declare again to use them here.
ARG ASTERISK_VERSION=22.11.0
ARG DEBIAN_FRONTEND=noninteractive

# Image metadata (OCI standard labels). Asterisk itself is GPL-2.0.
LABEL org.opencontainers.image.title="voip-lab-asterisk" \
      org.opencontainers.image.description="Asterisk built from source for voip-lab" \
      org.opencontainers.image.version="${ASTERISK_VERSION}" \
      org.opencontainers.image.licenses="GPL-2.0-only"

# Runtime libraries only (the non -dev counterparts of stage 1), plus:
#   gettext-base     provides envsubst for the *.tmpl config templates
#   ca-certificates  HTTPS from res_curl
#   tzdata           time zones, so TZ in docker-compose.yml works
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libedit2 libjansson4 libxml2 libxslt1.1 libsqlite3-0 libuuid1 \
      libssl3t64 libsrtp2-1 libcurl4t64 libspeexdsp1 libodbc2 \
      gettext-base ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

# Unprivileged system user and group that will run Asterisk.
RUN groupadd --system asterisk \
 && useradd --system --gid asterisk --home-dir /var/lib/asterisk \
      --no-create-home --shell /usr/sbin/nologin asterisk

# Copy everything "make install" produced in stage 1: binaries, modules,
# libasteriskpj (bundled pjproject), sounds, MOH and empty directories.
COPY --from=build /staging/ /

# - ldconfig: register the new shared libraries in /usr/lib.
# - Create the runtime directories and give them to the asterisk user.
#   /etc/asterisk-src is the mount point of the read-only repo config.
# - Fail the build if any module needs a library missing in this stage.
RUN ldconfig \
 && mkdir -p /etc/asterisk /etc/asterisk-src /var/lib/asterisk \
      /var/spool/asterisk /var/log/asterisk /var/run/asterisk /var/cache/asterisk \
 && chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk \
      /var/spool/asterisk /var/log/asterisk /var/run/asterisk /var/cache/asterisk \
 && ! ldd /usr/sbin/asterisk /usr/lib/asterisk/modules/*.so | grep 'not found'

# Entrypoint copied last: it changes more often than anything above, so
# editing it does not invalidate the (expensive) compile layers.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

# From here on, and at container start, run as "asterisk" (not root).
USER asterisk
WORKDIR /var/lib/asterisk

# Documentation only: SIP signaling and the RTP range (must match rtp.conf).
# Ports are actually published in docker-compose.yml.
EXPOSE 5060/udp 10000-10049/udp

# Entrypoint renders the config, then exec's the CMD.
#   -f    stay in the foreground (the container lives as long as Asterisk)
#   -n    no ANSI colors in docker logs
#   -vvv  verbosity level 3
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["asterisk", "-f", "-n", "-vvv"]
