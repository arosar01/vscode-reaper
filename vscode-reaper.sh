#!/bin/bash

set -u

PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Remote editor/server markers matched against the full ps command line.
# Add future remote editor/server markers here if needed.
PATTERNS=(
  '[.]vscode-server'
  '[.]cursor-server'
)

# Process owners to skip, even if their command line matches.
EXCLUDE_USERS=(
  root
)

# Number of passes and delay between passes.
KILL_PASSES="${KILL_PASSES:-3}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

join_by_pipe() {
  local IFS='|'
  echo "$*"
}

# Build regex strings from the arrays above.
PAT="${PAT:-$(join_by_pipe "${PATTERNS[@]}")}"
EXCLUDE_RE="${EXCLUDE_RE:-^($(join_by_pipe "${EXCLUDE_USERS[@]}"))$}"

MODE="${1:-}"

# Find matching local processes, excluding this script and its parent process.
find_matches() {
  ps ww -eo pid=,ppid=,user:32=,args= |
    awk -v pat="$PAT" -v excl="$EXCLUDE_RE" -v self="$$" -v parent="$PPID" \
      '$1 != self && $1 != parent && $3 !~ excl && $0 ~ pat {print}'
}

if [[ "$MODE" != "" && "$MODE" != "--kill" ]]; then
  echo "Usage: $0 [--kill]" >&2
  exit 2
fi

if [[ "$MODE" == "--kill" && "$EUID" -ne 0 ]]; then
  echo "ERROR: --kill mode must run as root." >&2
  exit 1
fi

MATCHES="$(find_matches || true)"

if [[ -z "$MATCHES" ]]; then
  if [[ "$MODE" != "--kill" ]]; then
    echo "No matching remote editor/server processes found." >&2
  fi
  exit 0
fi

if [[ "$MODE" != "--kill" ]]; then
  echo "$MATCHES"
  exit 0
fi

for pass in $(seq 1 "$KILL_PASSES"); do
  MATCHES="$(find_matches || true)"

  if [[ -z "$MATCHES" ]]; then
    [[ "$pass" -lt "$KILL_PASSES" ]] && sleep "$SLEEP_SECONDS"
    continue
  fi

  echo "Kill pass $pass of $KILL_PASSES:"
  echo "$MATCHES"

  mapfile -t PIDS < <(echo "$MATCHES" | awk '{print $1}')
  kill -KILL -- "${PIDS[@]}" 2>/dev/null || true

  [[ "$pass" -lt "$KILL_PASSES" ]] && sleep "$SLEEP_SECONDS"
done

exit 0
