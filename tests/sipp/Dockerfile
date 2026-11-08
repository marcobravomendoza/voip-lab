# syntax=docker/dockerfile:1
# SIPp (SIP traffic generator) for the lab tests.
# Debian packages it as "sip-tester" (built with pcap support), so no
# compilation is needed.
FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends sip-tester \
 && rm -rf /var/lib/apt/lists/*

# Scenarios are mounted here read-only by docker-compose.yml.
WORKDIR /scenarios

# Unprivileged user; SIPp only needs unprivileged UDP ports.
RUN useradd --system --no-create-home --shell /usr/sbin/nologin sipp
USER sipp

# "docker compose run sipp <args>" passes <args> straight to sipp.
ENTRYPOINT ["sipp"]
CMD ["-v"]
