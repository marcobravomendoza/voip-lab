# Phase 1: Asterisk in a container (week 1)

Goal: Asterisk 22 LTS built from source, running in Docker, with two
softphones calling each other and automated smoke tests.

## What was built

| Piece | Where |
|-------|-------|
| Multi-stage Asterisk image (22.11.0, non-root) | `asterisk/Dockerfile` |
| Config rendering (`*.tmpl` + `LAB_*` variables only) | `asterisk/entrypoint.sh` |
| Core, PJSIP, RTP, CDR, tones, features config | `asterisk/config/` |
| Dialplan: internal calls, echo test, hello world, 404 | `asterisk/config/extensions.conf` |
| Lab definition: `voip_net`, fixed IP, ports, volumes, healthcheck | `docker-compose.yml` |
| SIPp image and scenarios | `tests/sipp/` |
| Smoke tests (8 checks) | `tests/phase1/smoke.sh` |

## Deliverable

```bash
make up && make test-phase1
```

Expected: 8 `PASS` lines and `Result: all checks passed`, exit code 0
(see `docs/testing.md`). Manually: 1001 and 1002 registered in Linphone, a
call between them with two-way audio, 600 echoes your voice, 601 plays
"hello world", 1004 is rejected with `404 Not Found`.

## What to dial

| Number | What happens |
|--------|--------------|
| 1001-1003 | Calls that extension for 20 s; both sides can transfer (`##` blind, `*2` attended) |
| 600 | Echo test: plays instructions, then echoes your audio |
| 601 | Plays "hello world" and hangs up |
| anything else | Rejected with Q.850 cause 1, sent as SIP `404 Not Found` |

## Asterisk concepts, compared with a SIP proxy

| Concept | Asterisk | Kamailio equivalent |
|---------|----------|---------------------|
| Role | B2BUA: two independent SIP dialogs per call | Proxy: one dialog end to end |
| Call leg | Channel (`PJSIP/1001-00000004`) | One side of a dialog |
| Joining legs | Bridge (`native_rtp`, `simple_bridge`, `softmix`) | No media; RTPengine relays it |
| Routing logic | Dialplan (`extensions.conf`), contexts and extensions | `request_route` script |
| Identity / location | `endpoint`, `auth`, `aor` objects in `pjsip.conf` | `subscriber` table, `usrloc` |
| Correlating legs | LinkedID (UniqueID of the first channel) | Call-ID |
| Transactions | Handled inside pjproject, invisible to the dialplan | `tm`, visible in the script |
| Config check | Syntax at load time; app arguments only when executed | `kamailio -c` checks the whole script |

## Useful CLI commands

```
pjsip show endpoints | contacts | transports
dialplan show from-internal
core show channels            # live calls, one line per channel
bridge show all               # bridges and their technology
core set verbose 5            # see each dialplan step as it runs
module show like pjsip
```

## What I learned

- **Asterisk is a B2BUA.** A call between two phones shows two SIP dialogs
  with different Call-IDs in sngrep, and two channels in `core show channels`.
  The CDR joins both legs in one record (`channel` and `dstchannel`).
- **NAT behind Docker:** Asterisk must advertise the host LAN IP in Contact and
  SDP (`external_*_address`) to peers outside `local_net`. Advertising the
  container IP in the SDP would typically cause one-way audio.
- **Bridge technology depends on features, not only codecs:** with transfer
  features enabled in `Dial()` (`tT`), the call used `simple_bridge` instead
  of `native_rtp`, because Asterisk must watch the DTMF stream.
- **`duration` vs `billsec`** in the CDR: from call start vs from answer; the
  difference is ringing time.
- **The dialplan is only syntax-checked at load time.** `Answer(i)` loaded
  fine although `i` was in the delay argument; arguments are validated when a
  call runs that line. Test with real calls.
- **`autoload=yes` loads modules that want config files.** A clean startup
  needed a documented `noload` list and a few minimal files. Modules have
  dependency chains: disabling `res_websocket_client` silently took down
  `res_ari`, `app_stasis` and a dozen more.
- **SIP transactions bite test tools too:** identical Call-ID and branch in
  two quick SIPp runs made Asterisk replay a cached `200 OK` to a REGISTER
  with a wrong password (false PASS).
- **Docker details:** `/var/run` is a symlink on Debian (breaks `COPY` of a
  directory over it); `docker compose run` recreates dependencies whose
  config changed (use `--no-deps` in tests); `restart` does not re-read
  `.env`, `up -d` does.
- **The repo is the source of truth.** `/etc/asterisk` is regenerated on every
  start; edit `asterisk/config/` and run `make reload`.
