# voip-lab

Reproducible VoIP lab with Asterisk, Kamailio and RTPengine in Docker, built
from scratch as a learning project.

<!-- CI badge is added once the GitHub repository and workflow exist (week 1). -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Architecture

_Phase 1 diagram coming in week 1 (see `docs/architecture.md`)._

## Roadmap

| Tag  | Week | Content | Status |
|------|------|---------|--------|
| v0.1 | 1 | Asterisk built from source in Docker, 2 softphones, SIPp smoke tests | 🚧 in progress |
| v0.2 | 2 | PJSIP in depth, NAT, codecs, debugging provoked failures | ⏳ planned |
| v0.3 | 3 | Dialplan, voicemail, music on hold, IVR | ⏳ planned |
| v0.4 | 4 | Kamailio + RTPengine in front of Asterisk, SIP trunk, CDR, security | ⏳ planned |
| v0.5 | 5 | Call queues (app_queue) | ⏳ planned |
| v0.6 | 6 | Recording, queue_log and CDR in a database, Grafana | ⏳ planned |
| v0.7 | 7 | AMI, ARI and AGI with Python | ⏳ planned |
| v0.8 | 8 | FreePBX | ⏳ planned |
| v1.0 | 9 | TLS/SRTP, backup and upgrade, final release | ⏳ planned |

## Quick start

Requirements: Linux host with Docker Engine and Docker Compose v2, `make`.

```bash
git clone <repo-url> voip-lab && cd voip-lab
cp .env.example .env      # set LAB_HOST_IP and the passwords
make build                # first build compiles Asterisk (~5 min)
make up
make test-phase1
```

## What to dial from a softphone

_Coming in week 1._

## Repository layout

```
asterisk/      Asterisk Dockerfile, entrypoint and configuration
tests/sipp/    SIPp image and reusable scenarios
tests/phaseN/  smoke tests per phase
docs/          architecture, testing matrix, ADRs, one page per phase
```

## Sample test output

_Coming in week 1._

## Architecture Decision Records

_Coming in week 1 (`docs/adr/`)._

## What I learned

_Updated every week._

## License

[MIT](LICENSE)
