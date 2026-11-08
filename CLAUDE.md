# CLAUDE.md — voip-lab

Guidance for Claude Code in every session of this project. Read PROGRESS.md at
the start of each session to know where we are.

## Context (about the user)

- VoIP engineer, 5+ years on carrier platforms: Kamailio (routing development and
  bug fixing, reads its source), RTPengine, OpenSIPS, FreeSWITCH. SIP/RTP
  troubleshooting with sngrep, Wireshark and Homer. Prometheus/Grafana.
  Linux intermediate, little Docker experience, CKA and CCNA.
- Asterisk: almost none. Goals: month 1 = real basic level for the CV; month 2 =
  contact center on Asterisk (queues, recording, reporting, AMI/ARI) and FreePBX.
- Hardware: Fedora Workstation laptop, i3 (4 threads), 8 GB RAM. Watch resource
  usage and WARN before starting anything heavy (compilations, FreePBX, many
  containers at once).
- Docker CE + Compose v2, NOT Podman. If podman or podman-docker show up, warn
  about the conflict.
- SELinux enforcing: bind mounts need `:z` (shared) or `:Z` (private) labels.
- firewalld active (zone `public`): if anything uses `network_mode: host`, tell the
  user exactly which ports to open.
- Softphones: Linphone on a Mac in the same LAN and on a mobile phone.

## Rules

- Explain every new Asterisk, FreePBX and Docker concept **in Spanish** before using
  it. Comment config files line by line. Do NOT explain SIP / Kamailio / RTPengine
  from scratch: compare Asterisk concepts with them instead.
- Step by step: never move to the next phase until the user confirms the current
  one works.
- Division of work (agreed 2026-11-02; the goal is the user's real skill, not
  just the repo, within the 3-4 h/week budget):
  - The USER writes the core Asterisk config that interviews ask about
    (dialplan, key PJSIP objects, queues, AMI/ARI logic), drives the CLI and
    debugs. Claude explains the concept, gives requirements, then reviews and
    verifies what the user wrote. Do not write those files for the user.
  - CLAUDE does infrastructure and boilerplate (Docker, compose, Makefile, CI,
    test scripts, small default-heavy configs, doc drafts) in parallel, so the
    schedule does not slip.
  - Each week includes one small challenge done without help, and week 2
    includes rewriting pjsip.conf.tmpl from requirements.
- Never install anything, never use sudo, never `git push` without asking first.
  Give the exact commands and let the user run sudo commands.
- Every week ends with: a verifiable deliverable (command + expected output),
  automated tests in `tests/<phase>/` when possible, a page in `docs/` with what
  was learned, Conventional Commits, and a tag `vX.Y`.
- Before calling something done, run and verify it (build, `docker compose ps`,
  tests). If it cannot be verified, say so clearly.
- Everything generic, written from scratch, open source. No company data, IPs or
  configs. Secrets only in `.env` (git-ignored); the repo ships `.env.example`.
- Repository content (README, comments, docs, commits) in plain English.
  Explanations to the user in Spanish. User's Spanish notes go in `notes/`
  (git-ignored).
- At the end of every session update PROGRESS.md: done, pending, open questions,
  next step.

## Target architecture (built in phases)

Docker network `voip_net`, bridge, subnet `172.28.0.0/24`, fixed IPs:

| Service      | IP            |
|--------------|---------------|
| asterisk     | 172.28.0.10   |
| kamailio     | 172.28.0.20   |
| database     | 172.28.0.30   |
| grafana      | 172.28.0.40   |
| python apps  | 172.28.0.50   |
| sipp         | 172.28.0.100  |

- **Phase 1 (weeks 1-3):** softphones register directly on Asterisk. Asterisk
  publishes `5060/udp` and RTP `10000-10049/udp` (same range in `rtp.conf`).
  Behind Docker NAT, so `pjsip.conf` uses `local_net`,
  `external_signaling_address` and `external_media_address` = host LAN IP
  (`LAB_HOST_IP` in `.env`).
- **Phase 2 (week 4+):** Kamailio publishes `5060/udp` and is the only SIP entry
  point. Asterisk moves to internal port `5080` (not published). RTPengine runs
  with `network_mode: host` and handles media and NAT.
- Recommend `"userland-proxy": false` in `/etc/docker/daemon.json` before
  publishing UDP ranges (one docker-proxy process per published port otherwise).

## Technical decisions

- **Asterisk image:** no official image. Built from official source
  (downloads.asterisk.org), current LTS, multi-stage Dockerfile: build stage with
  bundled pjproject, runtime stage with only runtime libs, unprivileged user
  `asterisk`, version via `ARG ASTERISK_VERSION`. First build takes 10-20 min on
  this laptop: warn before starting it. Measured 2026-11-02: ~5 min uncached (3.6 min compile), seconds when cached.
  - Version check 2026-11-01: 22.x is the current stable LTS (22.11.0); 24.x LTS
    is still a release candidate. Use 22.x; upgrading to 24 is a week-9 exercise.
- Asterisk configs are mounted read-only from the repo. Files with secrets or the
  host IP are `*.tmpl` templates rendered by `entrypoint.sh` with `envsubst`,
  restricted to `LAB_*` variables (so dialplan `${EXTEN}` etc. stay untouched).
- `docker-compose.yml`: Asterisk healthcheck (`asterisk -rx "core show uptime"`),
  `init: true`, `restart: unless-stopped`, named volumes for logs and spool.
- SIPp in its own container, compose profile `test` (only for tests). Reusable XML
  scenarios in `tests/sipp/scenarios/` (digest-auth REGISTER, authenticated call…).
- Each phase has `tests/<phase>/smoke.sh`: prints PASS/FAIL per check, exit code =
  number of failures (CI-friendly).
- Makefile targets: `help, up, down, build, cli, logs, ps, sngrep, lint,
  test-phaseN`.
- GitHub Actions `.github/workflows/ci.yml`: `docker compose config`, shellcheck,
  build images, start the lab, run smoke tests.
- Important decisions as ADRs in `docs/adr/` (context, decision, consequences).
- License: MIT.

## Repository layout

```
voip-lab/
  asterisk/          Dockerfile, entrypoint.sh, config/ (one file per module)
  kamailio/          week 4
  rtpengine/         week 4
  db/                week 6 (CDR and queue_log schema)
  observability/     week 6 (grafana/ provisioned as code)
  apps/              week 7 (Python: AMI, ARI, AGI)
  tests/sipp/        SIPp Dockerfile and scenarios/
  tests/phaseN/      smoke.sh per phase
  docs/              architecture.md (Mermaid + port table), testing.md (test
                     matrix), troubleshooting.md, adr/, img/, one page per phase
  notes/             user's Spanish notes (git-ignored)
  docker-compose.yml, Makefile, .env.example, .gitignore, LICENSE, README.md,
  CLAUDE.md, PROGRESS.md
```

## Conventions

- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`,
  `ci:`, `refactor:`), scope optional (`feat(asterisk): ...`).
- Tags: one per week, `v0.1` … `v1.0`.
- Env vars for templates: prefix `LAB_` only.
- Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, must pass shellcheck.
- Volumes: always add `:z`/`:Z` on bind mounts; config mounts `:ro,z`.

## README (English, completed week by week)

Title + one-line value ("Reproducible VoIP lab with Asterisk, Kamailio and
RTPengine in Docker, built from scratch as a learning project"), CI and license
badges, architecture diagram, roadmap table (v0.1-v1.0 + status), quick start
(clone, `cp .env.example .env`, `make up`, `make test-phase1`), what to dial from a
softphone, repo layout, sample test output, ADR links, "What I learned", license.

## Plan

| Week | Content | Tag |
|------|---------|-----|
| 1 | Environment, repo, Asterisk in a container, architecture and CLI, 2 softphones calling each other, first SIPp tests | v0.1 |
| 2 | PJSIP in depth (endpoints/aors/auth/identify, transports, NAT, RTP, codecs), debug 4 provoked failures | v0.2 |
| 3 | Dialplan, voicemail, music on hold, simple IVR | v0.3 |
| 4 | Kamailio (registrar + dispatcher) + RTPengine in front of Asterisk, SIP trunk, CDR, basic security; full compose, diagram, README | v0.4 |
| 5 | Queues with app_queue (strategies, agents, pauses, overflow) | v0.5 |
| 6 | MixMonitor, queue_log and CDR in a DB, SIPp test calls, Grafana panel | v0.6 |
| 7 | AMI, ARI, AGI with Python (queue status, click-to-call, ARI app) | v0.7 |
| 8 | FreePBX end to end (install, extensions, trunk, routes, IVR, queues, recordings, time conditions, reports, backup, mapping to Asterisk files). VICIdial theory only | v0.8 |
| 9 (~2 h) | TLS/SRTP, Asterisk backup and upgrade, final README, release v1.0, interview questions, LinkedIn post, CV line | v1.0 |
