# Troubleshooting

Problems met while building the lab, with symptom, cause and fix.
Grows every week.

## Tools

```bash
make sngrep                         # SIP on the lab bridge (needs sudo)
make cli                            # Asterisk CLI
docker compose logs -f asterisk     # console output
docker compose exec asterisk tail -f /var/log/asterisk/messages.log
docker compose exec asterisk tail -f /var/log/asterisk/security.log
```

In the CLI: `pjsip set logger on` (SIP messages), `rtp set debug on` (RTP
packets), `core set verbose 5` (dialplan steps).

## Softphone does not register

| Symptom | Likely cause | Check / fix |
|---------|--------------|-------------|
| No REGISTER at all in sngrep | Packets do not reach the host: different Wi-Fi, client isolation on the access point, host firewall | Same network for phone and host; test `sudo firewall-cmd --zone=public --add-port=5060/udp --add-port=10000-10049/udp` (runtime only) |
| `401` in a loop | Wrong user or password | `security.log` shows `ChallengeResponseFailed` or `InvalidAccountID` |
| Registered, then `Unavail` in `pjsip show contacts` | Phone app asleep (mobile without push) or IP changed | Keep the app in the foreground; check the contact IP |

## Calls

| Symptom | Likely cause | Check / fix |
|---------|--------------|-------------|
| One-way audio | Private IP advertised in SDP, or RTP range not published | SDP `c=` must be `LAB_HOST_IP` for LAN phones; `rtp.conf` range = published range |
| Call drops after ~32 s | ACK never arrives: wrong Contact advertised | `external_signaling_address` must be `LAB_HOST_IP` |
| Dialed number goes to the wrong extension | Pattern without `_`, or a broader pattern wins | `dialplan show <number>@from-internal`: the first match wins |

## Containers and tests

| Symptom | Cause | Fix |
|---------|-------|-----|
| Image build fails at `COPY --from=build /staging/ /` with "cannot copy to non-directory: .../var/run" | `/var/run` is a symlink to `/run` on Debian | Move staged `/var/run` content to `/run` before the copy (done in the Dockerfile) |
| Config change in `.env` not applied after `docker compose restart` | `restart` keeps the old container environment | `docker compose up -d` recreates the container |
| A REGISTER with a wrong password "passes" in SIPp | Same Call-ID/branch as a previous run within 32 s: Asterisk replays the cached response | Unique `run_id` per SIPp run (see `docs/testing.md`) |
| Asterisk gets recreated while running tests | `docker compose run` also updates dependencies | `docker compose run --no-deps` |
| Startup log full of `Unable to load config file` | `autoload=yes` loads modules without config | `noload` in `modules.conf` or a minimal config file |
