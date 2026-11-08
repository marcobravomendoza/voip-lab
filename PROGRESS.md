# PROGRESS

## Week 1 — in progress (started 2026-11-02)

### Done
- Session 0 (2026-11-01): host checked; Docker CE 29.9, git, make, sngrep,
  shellcheck installed by the user; user in docker group; daemon.json with
  `userland-proxy: false` and log rotation.
- Point 1: git repo, .gitignore, LICENSE (MIT), .env.example, Makefile, README
  skeleton. `.env` created locally (host IP 192.168.1.157, random passwords).
- Point 2: multi-stage Asterisk 22.11.0 Dockerfile + entrypoint.sh (envsubst
  restricted to LAB_*). Image 147 MB compressed, runs as uid 999.
  Fixed: /var/run symlink vs COPY.
- Point 3: all phase 1 configs. Startup with zero ERROR/WARNING (noload list +
  minimal files for core modules). extensions.conf written by the user
  (3 review rounds, commit c7f8720).
- Point 4: docker-compose.yml (voip_net, fixed IP, ports, volumes,
  healthcheck), tzdata + LAB_TZ, `make reload`. Lab verified healthy in 15 s,
  ~45 MiB RAM.

- Point 5: CLI architecture tour done by the user (answers in notes/).
- Point 6: 1001 (Mac) and 1002 (mobile) registered, 601/600/1001->1002 calls,
  1004 -> 404, CDR reviewed. Bridge was simple_bridge (DTMF features tT).
  Firewalld: published ports reachable from the LAN without opening ports.
- Point 7: SIPp image + 2 scenarios + tests/phase1/smoke.sh, 8/8 PASS (~10 s).
  Found and fixed: identical Call-ID/branch across runs made pjproject replay
  a cached 200 OK (false PASS); "compose run" recreated Asterisk on .env
  change (fixed with --no-deps). Verified tests fail when credentials differ.

- Point 8: docs/architecture.md, testing.md, phase-1-asterisk.md,
  troubleshooting.md, ADR 0001/0002, .github/workflows/ci.yml, README week 1
  sections. CI simulated locally from a fresh clone with .env.example:
  lint OK, up healthy in 8.5 s, 8/8 PASS. Not verified: the CI image build
  with build-push-action + GHA cache (only runs on GitHub).
- User notes: answers 1-6 reviewed (audio OK both ways, note 3 rewritten).

### Pending (week 1)
- 9: GitHub repo + push (user), CI green, tag v0.1.

### Open questions
- Schedule: realistic estimate is 12-14 weeks at the current pace. Proposal:
  keep weeks 1-4 depth, trim extras in weeks 6-9 (simple Grafana panel,
  minimal ARI app, FreePBX essentials, drop VICIdial) to land at ~11 weeks.
  User decides at the end of week 1.
- Git email is public in commits; switch to the GitHub noreply address
  before the first push if desired.
- Wi-Fi DHCP: reserve 192.168.1.157 in the router.
- One unexpected full recompile on the first `docker compose build`
  (cache not reused from the earlier `docker build`); later builds cached.

### Next step
Point 9: decide commit email, create GitHub repo (web, gh not installed),
replace OWNER in the README badge, push (user), CI green, tag v0.1.
