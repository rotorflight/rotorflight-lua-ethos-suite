#!/usr/bin/env bash
# Kill any previous deploy/serial processes recorded in PID files (Unix/macOS).
set -euo pipefail

# Python writes its PID files to tempfile.gettempdir()
# On Linux this is usually /tmp; on macOS it’s $TMPDIR (e.g., /var/folders/...).
TMP_ROOT="${TMPDIR:-/tmp}"

kill_from_pidfile() {
  local pf="$1"
  [[ -f "$pf" ]] || return 0

  # read PID (strip whitespace)
  local pid
  pid="$(tr -d ' \t\r\n' < "$pf" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || { rm -f "$pf"; return 0; }

  # send TERM, then KILL if still alive after a short grace period
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    # wait up to ~3s
    for _ in 1 2 3 4 5 6; do
      sleep 0.5
      kill -0 "$pid" 2>/dev/null || break
    done
    # force if needed
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi

  rm -f "$pf" 2>/dev/null || true
}

kill_from_pidfile "$TMP_ROOT/rfdeploy-copy.pid"
kill_from_pidfile "$TMP_ROOT/rfdeploy-serial.pid"
