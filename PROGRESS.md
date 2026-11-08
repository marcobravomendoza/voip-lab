# PROGRESS

## Session 0 — 2026-11-01 (setup check)

### Done
- Created `CLAUDE.md` (context, rules, architecture, conventions, plan) and this file.
- Checked the host (Fedora 44, i3 4 threads, 7.6 GiB RAM, ~4.4 GiB available,
  46 GB free disk):
  - Missing: Docker CE + Compose plugin, git, make, sngrep, shellcheck.
  - Present: envsubst, curl.
  - No Podman / podman-docker / moby-engine installed (no conflict).
  - SELinux: Enforcing. firewalld: running, default zone `public` on `wlp0s20f3`.
  - Host LAN IP: 192.168.1.157/24 (Wi-Fi, gateway 192.168.1.1) -> `LAB_HOST_IP`.
  - `/etc/docker/daemon.json` does not exist yet.
- Asterisk version check: 22.11.0 is the current stable LTS; 24.0.0 LTS is still
  rc4. Decision: build 22.x (ADR to be written in week 1).

### Pending (user, with sudo)
- Install Docker CE from the official repo, git, make, sngrep, shellcheck.
- Add user to `docker` group, create `/etc/docker/daemon.json`
  (`userland-proxy: false`), open firewalld ports for phase 1.
- Install Linphone on the Mac and the phone.

### Open questions
- Wi-Fi IP may change (DHCP): consider a DHCP reservation for 192.168.1.157 in
  the home router, or update `LAB_HOST_IP` when it changes.

### Next step
**Week 1**: verify installs (`docker run hello-world`, `docker compose version`),
`git init`, repo skeleton, multi-stage Asterisk Dockerfile (first build 10-20 min),
compose with `voip_net`, 2 softphones calling each other, first SIPp test.
