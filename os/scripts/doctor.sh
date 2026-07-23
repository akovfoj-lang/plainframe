#!/usr/bin/env bash
# doctor.sh — one-shot health check: composes every canonical check, adds none.
#
# Usage: os/scripts/doctor.sh            run all checks, exit 1 if any fail
#        os/scripts/doctor.sh --setup    wire the tracked pre-commit hook, then check
#
# Policy lives in the individual scripts (law 6) — doctor only orchestrates:
# prerequisites, gen-map/gen-status/gen-commands --check, markers.sh, hook wiring,
# and a warn-only grep over staged changes for common secret shapes (PF-014).

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

case "${1:-}" in
  ""|--setup) ;;
  *) echo "usage: os/scripts/doctor.sh [--setup]" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

if ! command -v git >/dev/null 2>&1; then
  echo "FAIL: git not found — Plainframe needs git and a POSIX shell, nothing else"
  exit 1
fi
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "FAIL: not a git repo — clone your copy of the template first"
  exit 1
fi

if [ "${1:-}" = "--setup" ]; then
  git config core.hooksPath os/scripts/hooks
  echo "OK: pre-commit hook wired (core.hooksPath = os/scripts/hooks)"
fi

FAIL=0
for c in gen-map gen-status gen-commands; do
  if /bin/bash "os/scripts/$c.sh" --check; then
    :
  else
    rc=$?
    case $rc in
      1) echo "FAIL: os/scripts/$c.sh --check — stale (exit 1)" ;;
      *) echo "FAIL: os/scripts/$c.sh --check — internal error (exit $rc), not a simple staleness issue" ;;
    esac
    FAIL=1
  fi
done

if /bin/bash os/scripts/markers.sh >/dev/null; then
  echo "OK: markers.sh runs clean"
else
  echo "FAIL: markers.sh errored"
  FAIL=1
fi

# Staged secrets (PF-014): a cheap grep over what's about to be committed for
# a few common credential shapes. This is NOT a security boundary — it
# catches nothing sophisticated, and a determined leak still gets through —
# just a tripwire before a commit ships something that belongs in .env or a
# password manager instead (see README's "Data classification"). Warn-only:
# never sets FAIL, never blocks a commit by itself.
SECRET_PATTERN='AKIA[0-9A-Z]{16}|-----BEGIN[A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}'
secret_hits=$(git diff --cached -U0 -- . 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E "$SECRET_PATTERN" || true)
if [ -n "$secret_hits" ]; then
  echo "WARN: staged changes contain a common secret-shaped token (AWS key / private key header / Slack token) — verify nothing real is about to be committed:"
  printf '%s\n' "$secret_hits" | sed 's/^/  /'
else
  echo "OK: no common secret-shaped tokens found in staged changes"
fi

hp=$(git config core.hooksPath 2>/dev/null || true)
if [ "$hp" = "os/scripts/hooks" ]; then
  echo "OK: pre-commit hook wired"
else
  echo "note: pre-commit hook not wired — run os/scripts/doctor.sh --setup once"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "DOCTOR: failures above — regenerate what is stale, then rerun"
  exit 1
fi
echo "OK: doctor — all checks passed"
