# Testing

## How to run

```bash
make up            # waits until Asterisk is healthy
make test-phase1   # exit code = number of failed checks
```

SIPp runs in a throw-away container (`sipp` service, compose profile `test`,
IP 172.28.0.100) and uses extension 1003, reserved for automated tests.
SIPp output is kept in `tests/phase1/results/` (git-ignored).

## Phase 1 test matrix

| # | Check | How | Expected | Automated |
|---|-------|-----|----------|-----------|
| 1 | Asterisk container healthy | `docker inspect` health status (healthcheck runs `core show uptime`) | `healthy` | yes |
| 2 | 3 PJSIP endpoints loaded | `pjsip show endpoints` | `Objects found: 3` | yes |
| 3 | UDP transport on 5060 | `pjsip show transports` | `transport-udp udp ... :5060` | yes |
| 4 | Dialplan loaded | `dialplan show 1001\|600\|601@from-internal` | every extension found | yes |
| 5 | REGISTER, valid credentials | SIPp `register_auth.xml` | 401 then 200 OK | yes |
| 6 | REGISTER, wrong password | SIPp `register_auth.xml` + `security.log` | SIPp fails and `ChallengeResponseFailed` logged for that Call-ID | yes |
| 7 | Authenticated call to 600, 3 s | SIPp `uac_auth_call.xml` | 401, 200 OK, BYE answered | yes |
| 8 | CDR written | new line in `cdr-csv/Master.csv` | `1003` -> `600`, `ANSWERED`, billsec >= 2 | yes |
| 9 | Softphone registration | Linphone 1001 / 1002, `pjsip show contacts` | `Avail` with RTT | manual |
| 10 | Call between softphones | 1001 -> 1002 | two-way audio, 2 SIP dialogs in sngrep | manual |
| 11 | Echo test / hello world | dial 600 / 601 | own voice echoed / prompt played | manual |
| 12 | Unknown number | dial 1004 | `404 Not Found` | manual |

## Sample output

```
Phase 1 smoke tests
-------------------
  PASS  asterisk container is healthy
  PASS  3 PJSIP endpoints loaded
  PASS  UDP transport listening on 5060
  PASS  dialplan loaded (1001, 600, 601 in from-internal)
  PASS  REGISTER 1003 with valid credentials -> 200 OK
  PASS  REGISTER 1003 with wrong password is rejected (security.log)
  PASS  authenticated call 1003 -> 600 for 3 s
  PASS  CDR written for the call (ANSWERED, billsec >= 2)
-------------------
Result: all checks passed
```

## Design notes

- **Unique Call-ID and Via branch per run.** SIPp runs as PID 1 in its
  container, so by default every run produces the same Call-ID and branch.
  A second run within 32 s (Timer J) was treated by Asterisk as a
  retransmission of the previous transaction, and the cached 200 OK was
  replayed even with a wrong password: a false PASS. Every run now passes
  `-key run_id <unique>` and `-cid_str "%u-%p-<unique>@%s"`.
- **Rejection is checked on both sides.** Check 6 requires SIPp to fail *and*
  `security.log` to contain `ChallengeResponseFailed` for that Call-ID.
- **Tests never restart the system under test.** `docker compose run` starts
  and may recreate dependencies when their config changed (for example a new
  `.env`). SIPp is run with `--no-deps`; check 1 covers Asterisk's health.
- **Tests were checked against failures**: with Asterisk stopped (check 1
  fails, the run aborts) and with mismatched credentials (checks 5, 7 and 8
  fail, exit code 3).

## Limitations

- SIPp sends no RTP: audio quality and NAT for media are covered by the
  manual softphone tests (9-12), not by the smoke tests.
- Check 4 only verifies that key extensions exist, not their behaviour; calls
  to 600 are exercised by check 7.
