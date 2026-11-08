#!/usr/bin/env bash
# Phase 1 smoke tests: Asterisk alone, softphones/SIPp register directly on it.
#
# Prints PASS/FAIL per check and exits with the number of failures
# (0 = all good), so CI can use the exit code directly.
#
# Requirements: the lab is running (make up) and .env exists.
# SIPp runs in a throw-away container from the "test" compose profile.
set -euo pipefail

# Always run from the repository root.
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

ASTERISK_IP="172.28.0.10"
TEST_EXT="1003"                       # extension reserved for automated tests
RESULTS_DIR="tests/phase1/results"    # SIPp output, git-ignored
CDR_FILE="/var/log/asterisk/cdr-csv/Master.csv"
SECURITY_LOG="/var/log/asterisk/security.log"

FAILURES=0
LAST_RUN_ID=""

mkdir -p "$RESULTS_DIR"

pass() { printf '  PASS  %s\n' "$1"; }
fail() {
  printf '  FAIL  %s\n' "$1"
  if [[ -n "${2:-}" ]]; then printf '        %s\n' "$2"; fi
  FAILURES=$((FAILURES + 1))
}

# Run an Asterisk CLI command inside the container.
ast() { docker compose exec -T asterisk asterisk -rx "$1"; }

# Read one variable from .env without sourcing the whole file.
env_value() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2-; }

# Number of lines of a file inside the Asterisk container (0 if missing).
remote_lines() {
  docker compose exec -T asterisk sh -c "[ -f '$1' ] && wc -l < '$1' || echo 0"
}

# Run SIPp once (-m 1) with a unique run id in the Call-ID and Via branch,
# so consecutive runs are never mistaken for retransmissions.
# --no-deps: never let "compose run" recreate/restart Asterisk (the system
# under test) when it detects config changes; check 1 covers its health.
# Usage: run_sipp <name-for-log> <sipp args...>
run_sipp() {
  local name="$1"; shift
  LAST_RUN_ID="$(date +%s)$RANDOM"
  docker compose --profile test run --rm -T --no-deps sipp \
    "$ASTERISK_IP:5060" -m 1 -nostdin -timeout 20s -timeout_error \
    -key run_id "$LAST_RUN_ID" -cid_str "%u-%p-${LAST_RUN_ID}@%s" \
    "$@" > "$RESULTS_DIR/$name.log" 2>&1
}

[[ -f .env ]] || { echo "ERROR: .env not found (cp .env.example .env)"; exit 1; }
PASSWORD="$(env_value "LAB_EXT_${TEST_EXT}_PASSWORD")"

echo "Phase 1 smoke tests"
echo "-------------------"

# 1. Container is running and its healthcheck reports healthy.
container_id="$(docker compose ps -q asterisk || true)"
health="$( [[ -n "$container_id" ]] && docker inspect -f '{{.State.Health.Status}}' "$container_id" || echo missing)"
if [[ "$health" == "healthy" ]]; then
  pass "asterisk container is healthy"
else
  fail "asterisk container is healthy" "status: $health (is the lab up? make up)"
  echo "-------------------"
  echo "Result: aborted, Asterisk is not running"
  exit "$FAILURES"
fi

# 2. The three PJSIP endpoints from pjsip.conf are loaded.
endpoints="$(ast "pjsip show endpoints" | grep -oE 'Objects found: [0-9]+' || true)"
if [[ "$endpoints" == "Objects found: 3" ]]; then
  pass "3 PJSIP endpoints loaded"
else
  fail "3 PJSIP endpoints loaded" "got: ${endpoints:-none}"
fi

# 3. The UDP transport listens on port 5060.
if ast "pjsip show transports" | grep -qE 'transport-udp +udp .*:5060'; then
  pass "UDP transport listening on 5060"
else
  fail "UDP transport listening on 5060"
fi

# 4. The dialplan is loaded: the key extensions exist in from-internal.
missing=""
for exten in 1001 600 601; do
  ast "dialplan show ${exten}@from-internal" | grep -q '=>' || missing+="$exten "
done
if [[ -z "$missing" ]]; then
  pass "dialplan loaded (1001, 600, 601 in from-internal)"
else
  fail "dialplan loaded (1001, 600, 601 in from-internal)" "missing: $missing"
fi

# 5. REGISTER with the right password succeeds (401 challenge, then 200 OK).
if run_sipp register_ok -sf /scenarios/register_auth.xml \
     -s "$TEST_EXT" -au "$TEST_EXT" -ap "$PASSWORD"; then
  pass "REGISTER $TEST_EXT with valid credentials -> 200 OK"
else
  fail "REGISTER $TEST_EXT with valid credentials -> 200 OK" "see $RESULTS_DIR/register_ok.log"
fi

# 6. REGISTER with a wrong password is rejected: SIPp must fail AND
#    security.log must contain ChallengeResponseFailed for this Call-ID.
if run_sipp register_bad -sf /scenarios/register_auth.xml \
     -s "$TEST_EXT" -au "$TEST_EXT" -ap "wrong-password-$RANDOM"; then
  fail "REGISTER $TEST_EXT with wrong password is rejected" "SIPp got a 200 OK"
elif docker compose exec -T asterisk grep -q \
       "ChallengeResponseFailed.*SessionID=\"[^\"]*${LAST_RUN_ID}@" "$SECURITY_LOG"; then
  pass "REGISTER $TEST_EXT with wrong password is rejected (security.log)"
else
  fail "REGISTER $TEST_EXT with wrong password is rejected" \
       "no ChallengeResponseFailed event in security.log"
fi

# 7. Authenticated call to 600 (echo test), held for 3 seconds.
cdr_before="$(remote_lines "$CDR_FILE")"
if run_sipp call_600 -sf /scenarios/uac_auth_call.xml \
     -s 600 -key caller "$TEST_EXT" -au "$TEST_EXT" -ap "$PASSWORD" -d 3000; then
  pass "authenticated call $TEST_EXT -> 600 for 3 s"
else
  fail "authenticated call $TEST_EXT -> 600 for 3 s" "see $RESULTS_DIR/call_600.log"
fi

# 8. That call wrote a new CDR line: src 1003, dst 600, ANSWERED, billsec >= 2.
sleep 1
new_cdrs="$(docker compose exec -T asterisk tail -n "+$((cdr_before + 1))" "$CDR_FILE" 2>/dev/null || true)"
if grep -qE "^\"[^\"]*\",\"$TEST_EXT\",\"600\",.*,[0-9]+,([2-9]|[1-9][0-9]+),\"ANSWERED\"" <<< "$new_cdrs"; then
  pass "CDR written for the call (ANSWERED, billsec >= 2)"
else
  fail "CDR written for the call (ANSWERED, billsec >= 2)" "new CDR lines: ${new_cdrs:-none}"
fi

echo "-------------------"
if [[ "$FAILURES" -eq 0 ]]; then
  echo "Result: all checks passed"
else
  echo "Result: $FAILURES check(s) failed"
fi
exit "$FAILURES"
