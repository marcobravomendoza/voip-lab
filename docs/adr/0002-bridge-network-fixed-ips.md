# ADR 0002: User-defined bridge network with fixed IPs

- Status: accepted
- Date: 2026-11-06

## Context

SIP and RTP carry IP addresses inside the messages (Via, Contact, SDP `c=`),
so every component must know which addresses are internal and which one to
advertise to the outside. Asterisk's NAT settings (`local_net`,
`external_*_address`), and later Kamailio's dispatcher list and RTPengine's
interfaces, need stable addresses.

Docker assigns container IPs dynamically by default, and the default bridge
network has no name resolution or predictable subnet.

## Decision

- One user-defined bridge network, `voip_net`, subnet `172.28.0.0/24`,
  gateway `172.28.0.1`, with a fixed Linux bridge name `br-voip_net` so that
  `sngrep -d br-voip_net` and tcpdump can capture lab traffic directly.
- A fixed IP per service: asterisk .10, kamailio .20, database .30,
  grafana .40, python apps .50, sipp .100.
- Only the ports softphones need are published on the host (phase 1:
  5060/udp and 10000-10049/udp on Asterisk). The Docker daemon runs with
  `userland-proxy: false`, so published UDP ports use kernel DNAT and keep the
  real source address of the phones.
- `network_mode: host` is reserved for RTPengine (phase 2), which must bind
  real host addresses and large port ranges.

## Consequences

- Addresses in config files are predictable and documented
  (`docs/architecture.md`).
- `local_net = 172.28.0.0/24` cleanly separates internal peers (SIPp, later
  Kamailio) from LAN peers that need the advertised host IP.
- The subnet must not collide with a network the host already uses; if it
  does, it has to change in `docker-compose.yml` and in `pjsip.conf.tmpl`.
- The network has a fixed name (`voip_net`), so only one copy of the lab can
  run on a host at a time.
- Publishing a small RTP range (50 ports, 25 call legs) keeps DNAT rules and
  firewall exposure small; enough for a lab.

## Alternatives considered

- **Default bridge with dynamic IPs:** addresses change between runs, which
  breaks NAT settings in SIP config.
- **`network_mode: host` for everything:** no NAT problems, but no isolation,
  port clashes with the host and less to learn about NAT, which is a core
  VoIP skill.
- **macvlan/ipvlan (containers with LAN IPs):** realistic, but needs a wired
  interface and router cooperation; macvlan usually does not work over Wi-Fi.
