# Architecture

The lab is built in phases. This page shows the current phase (1) and the
target architecture (phase 2, week 4 onwards).

## Phase 1: Asterisk only (weeks 1-3)

Softphones on the LAN register directly on Asterisk. Asterisk runs in a
container behind Docker's NAT, so it advertises the host LAN IP to them.

```mermaid
flowchart LR
  subgraph LAN["LAN (e.g. 192.168.1.0/24)"]
    mac["Linphone (Mac)<br/>ext 1001"]
    phone["Linphone (mobile)<br/>ext 1002"]
  end

  subgraph host["Docker host (LAB_HOST_IP)"]
    nat{{"Docker NAT<br/>5060/udp<br/>10000-10049/udp"}}
    subgraph voip_net["voip_net 172.28.0.0/24 (bridge br-voip_net)"]
      ast["asterisk<br/>172.28.0.10"]
      sipp["sipp (test profile)<br/>172.28.0.100<br/>ext 1003"]
    end
  end

  mac -- "SIP + RTP" --> nat
  phone -- "SIP + RTP" --> nat
  nat -- "DNAT" --> ast
  sipp -- "SIP (no NAT)" --> ast
```

How NAT is handled (`asterisk/config/pjsip.conf.tmpl`):

- `local_net = 172.28.0.0/24` (and loopback): destinations Asterisk reaches
  directly. SIPp lives here, so it sees the internal address 172.28.0.10.
- Everything else (the softphones) gets `external_signaling_address` in
  Via/Contact and `external_media_address` in the SDP `c=` line, both set to
  `LAB_HOST_IP`.
- `userland-proxy: false` in the Docker daemon keeps the real source IP of the
  phones, so `rewrite_contact`, `force_rport` and `rtp_symmetric` work.
- `direct_media = no`: media always goes through Asterisk.

### Configuration flow

```mermaid
flowchart LR
  repo["asterisk/config/<br/>(repo, source of truth)"] -- "bind mount :ro" --> src["/etc/asterisk-src"]
  env[".env (LAB_* values)"] -- "env_file" --> ep
  src --> ep["entrypoint.sh<br/>copy *.conf<br/>envsubst *.tmpl (LAB_* only)"]
  ep --> etc["/etc/asterisk<br/>(read by Asterisk)"]
```

`make reload` re-runs the render step and `core reload` without restarting
the container. Changes to `.env` need `docker compose up -d` (recreate).

## Target: phase 2 (week 4 onwards)

Kamailio becomes the only SIP entry point and RTPengine handles media and NAT.
Asterisk moves to an internal port and is no longer published.

```mermaid
flowchart LR
  phones["Softphones (LAN)"] -- "SIP 5060/udp" --> kam
  phones -- "RTP" --> rtpe
  trunk["SIP trunk (test)"] -- "SIP" --> kam

  subgraph host["Docker host"]
    rtpe["rtpengine<br/>network_mode: host"]
    subgraph voip_net["voip_net 172.28.0.0/24"]
      kam["kamailio 172.28.0.20<br/>registrar + dispatcher"]
      ast["asterisk 172.28.0.10<br/>port 5080 (internal)"]
      db[("database 172.28.0.30<br/>CDR, queue_log")]
      graf["grafana 172.28.0.40"]
      apps["python apps 172.28.0.50<br/>AMI / ARI / AGI"]
      sipp["sipp 172.28.0.100"]
    end
  end

  kam -- "SIP" --> ast
  kam -. "ng control" .-> rtpe
  ast --> db
  graf --> db
  apps -- "AMI / ARI" --> ast
  sipp --> kam
```

## IP plan

| Service      | IP            | Phase |
|--------------|---------------|-------|
| gateway      | 172.28.0.1    | 1     |
| asterisk     | 172.28.0.10   | 1     |
| kamailio     | 172.28.0.20   | 2     |
| database     | 172.28.0.30   | 2     |
| grafana      | 172.28.0.40   | 2     |
| python apps  | 172.28.0.50   | 2     |
| sipp         | 172.28.0.100  | 1     |

## Ports

| Port / range       | Proto | Service  | Published on host | Phase | Purpose |
|--------------------|-------|----------|-------------------|-------|---------|
| 5060               | UDP   | asterisk | yes               | 1     | SIP signaling |
| 10000-10049        | UDP   | asterisk | yes               | 1     | RTP/RTCP media (same range as `rtp.conf`) |
| 5060               | UDP   | kamailio | yes               | 2     | SIP entry point (replaces Asterisk's) |
| 5080               | UDP   | asterisk | no                | 2     | SIP, internal only |
| RTPengine range    | UDP   | rtpengine| host network      | 2     | media relay (firewalld rules needed) |

Phase 1 needs no firewalld changes on the host: Docker manages published
ports through its own firewalld zone (verified on Fedora with firewalld).
