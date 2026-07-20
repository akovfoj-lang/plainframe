#!/usr/bin/env bash
# doctor.sh — one-shot health check: composes every canonical check, adds none.
#
# Usage: os/scripts/doctor.sh            run all checks, exit 1 if any fail
#        os/scripts/doctor.sh --setup    wire the tracked pre-commit hook, then check
#
# Policy lives in the individual scripts (law 6) — doctor only orchestrates:
# prerequisites, gen-map/gen-status/gen-commands --check, markers.sh, hook wiring.

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
  if /bin/bash "os/scripts/$c.sh" --check; then :; else FAIL=1; fi
done

if /bin/bash os/scripts/markers.sh >/dev/null; then
  echo "OK: markers.sh runs clean"
else
  echo "FAIL: markers.sh errored"
  FAIL=1
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
