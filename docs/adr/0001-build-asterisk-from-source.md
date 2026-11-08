# ADR 0001: Build Asterisk from source in a multi-stage Dockerfile

- Status: accepted
- Date: 2026-11-02

## Context

The lab needs Asterisk in a container. There is no official Asterisk image.
Community images exist, but their versions, build options, base images and
update cadence are outside our control, and they hide how Asterisk is built,
which is part of what this project wants to learn. Distribution packages lag
behind the current LTS release.

The host is a small laptop (4 threads, 8 GB RAM), and the image must also
build and run on GitHub Actions runners.

## Decision

Build Asterisk from the official tarball (downloads.asterisk.org) in a
multi-stage Dockerfile (`asterisk/Dockerfile`):

- **Version:** current LTS, 22.x (24.x LTS was still a release candidate on
  2026-11-01), set with `ARG ASTERISK_VERSION` / `LAB_ASTERISK_VERSION`.
- **Integrity:** the tarball is checked against the official `.sha256` file.
- **Build stage:** Debian 13 slim + compiler and `-dev` packages, bundled
  pjproject, `menuselect` with `BUILD_NATIVE` disabled (portable binaries)
  and only u-law sounds (en, es) plus u-law music on hold. Installed with
  `DESTDIR` into a staging directory and stripped.
- **Runtime stage:** Debian 13 slim with runtime libraries only, unprivileged
  user `asterisk` (uid 999), and an `ldd` check that fails the build if any
  module misses a library.
- **Configuration is not baked into the image:** it is mounted read-only from
  the repo and rendered by `entrypoint.sh` (see ADR 0002 and
  `docs/architecture.md`).

## Consequences

- Full control of version and modules; upgrading means changing one variable
  and rebuilding (an exercise planned for week 9).
- First build: about 5 minutes on the lab laptop; later builds come from the
  layer cache in seconds. CI uses the GitHub Actions cache for the same reason.
- Image: 147 MB compressed, no compiler inside.
- Optional modules whose `-dev` library is not installed are not built at all.
  ODBC and SRTP libraries are included now to avoid a rebuild in weeks 6 and 9.
- We own security updates: rebuilding on new Asterisk or Debian releases is
  our job.
- Pitfall found: on Debian `/var/run` is a symlink to `/run`, so the staged
  `/var/run` content is moved to `/run` before `COPY --from=build`.

## Alternatives considered

- **Community image:** fastest to start, but opaque and not under our control.
- **Debian/Fedora package:** simple, but older than the current LTS and with
  the distribution's module choices.
- **Single-stage build:** simpler Dockerfile, but a 1 GB+ image that ships a
  compiler.
