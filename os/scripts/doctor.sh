#!/usr/bin/env bash
# doctor.sh — one-shot health check: composes every canonical check, adds none.
#
# Usage: os/scripts/doctor.sh            run all checks, exit 1 if any fail
#        os/scripts/doctor.sh --setup    wire the tracked git hooks, then check
#
# Policy lives in the individual scripts (law 6) — doctor only orchestrates:
# prerequisites, gen-map/gen-status/gen-desk/gen-commands --check, markers.sh,
# hook wiring, and the staged-secrets check (PF-014, PF-035): gitleaks when it
# is installed — a hit fails, as it blocks a commit — the warn-only pattern
# otherwise.

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

HOOKS="pre-commit commit-msg pre-push"

if [ "${1:-}" = "--setup" ]; then
  git config core.hooksPath os/scripts/hooks
  echo "OK: git hooks wired (core.hooksPath = os/scripts/hooks: $HOOKS)"
fi

FAIL=0
for c in gen-map gen-status gen-desk gen-commands; do
  [ -f "os/scripts/$c.sh" ] || continue
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

# Staged secrets — not a security boundary, a tripwire before a commit ships
# something that belongs in .env or a password manager (README's "Data
# classification"). Both call sites source lib/secrets.sh, so the rules
# cannot drift between this check and the pre-commit hook.
# shellcheck source=lib/secrets.sh
. "$ROOT/os/scripts/lib/secrets.sh"
if [ "$(secrets_scanner)" = gitleaks ]; then
  if staged_secret_scan >/dev/null 2>&1; then
    echo "OK: gitleaks finds no secrets in staged changes"
  else
    echo "FAIL: gitleaks found a secret in staged changes — the pre-commit hook will block this commit (run: gitleaks git --pre-commit --staged --redact -v)"
    FAIL=1
  fi
else
  secret_hits=$(staged_secret_hits)
  if [ -n "$secret_hits" ]; then
    echo "WARN: staged changes contain a secret-shaped token — verify nothing real is about to be committed:"
    printf '%s\n' "$secret_hits" | sed 's/^/  /'
  else
    echo "OK: no secret-shaped tokens in staged changes (basic pattern)"
  fi
  echo "note: gitleaks is not installed — secrets get only the basic pattern check, which warns but never blocks (macOS: brew install gitleaks)"
fi

hp=$(git config core.hooksPath 2>/dev/null || true)
if [ "$hp" = "os/scripts/hooks" ]; then
  missing=""
  for h in $HOOKS; do [ -x "os/scripts/hooks/$h" ] || missing="$missing $h"; done
  if [ -n "$missing" ]; then
    echo "FAIL: hooks wired, but not executable:$missing — git skips a hook it cannot run (chmod +x os/scripts/hooks/*)"
    FAIL=1
  else
    echo "OK: git hooks wired ($HOOKS)"
  fi
else
  echo "note: git hooks not wired — run os/scripts/doctor.sh --setup once per clone"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "DOCTOR: failures above — regenerate what is stale, then rerun"
  exit 1
fi
echo "OK: doctor — all checks passed"
