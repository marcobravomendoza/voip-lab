#!/usr/bin/env bash
# Asterisk container entrypoint.
#
# 1. Copies the read-only repo config (mounted at $SRC_DIR) into /etc/asterisk.
# 2. Renders every *.tmpl file with envsubst, replacing ONLY ${LAB_*} variables,
#    so dialplan variables such as ${EXTEN} are left untouched.
# 3. Fails if a template uses a LAB_* variable that is not set.
# 4. exec's the command (Asterisk by default), replacing this shell.
#
# Usage:
#   entrypoint.sh [command...]   render config, then run the command
#   entrypoint.sh render         only render config (used by "make reload")
set -euo pipefail

SRC_DIR="${ASTERISK_CONFIG_SRC:-/etc/asterisk-src}"
DST_DIR="${ASTERISK_CONFIG_DST:-/etc/asterisk}"

log() { printf '[entrypoint] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

render_config() {
  [[ -d "$SRC_DIR" ]] || die "$SRC_DIR not found (is asterisk/config mounted?)"

  # Variable list for envsubst, e.g. "${LAB_HOST_IP} ${LAB_EXT_1001_PASSWORD} ".
  # envsubst only replaces the variables named in this list.
  local allowed="" var
  while read -r var; do
    allowed+="\${${var}} "
  done < <(compgen -e | grep '^LAB_' || true)

  # Start from an empty target dir so files removed from the repo disappear.
  find "$DST_DIR" -mindepth 1 -maxdepth 1 -delete

  local src name missing
  for src in "$SRC_DIR"/*; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    if [[ "$name" == *.tmpl ]]; then
      # Every ${LAB_*} used in the template must be set and non-empty.
      missing=""
      while read -r var; do
        [[ -n "${!var:-}" ]] || missing+="$var "
      done < <(grep -oE '[$][{]LAB_[A-Za-z0-9_]+[}]' "$src" | tr -d '{}$' | sort -u)
      [[ -z "$missing" ]] || die "$name uses unset variables: $missing(check .env)"

      envsubst "$allowed" < "$src" > "$DST_DIR/${name%.tmpl}"
      log "rendered $name -> ${name%.tmpl}"
    else
      cp "$src" "$DST_DIR/$name"
    fi
  done
  # Rendered files contain passwords: readable only by the asterisk user.
  find "$DST_DIR" -maxdepth 1 -type f -exec chmod 0640 {} +
}

if [[ "${1:-}" == "render" ]]; then
  render_config
  exit 0
fi

render_config
log "starting: $*"
exec "$@"
