# secrets.sh — staged-secrets grep (PF-014), shared by os/scripts/doctor.sh
# and os/scripts/hooks/pre-commit so the pattern lives in one place and the
# two call sites can never drift apart (law 3: one home per fact).
#
# Sourced, not executed. Requires the caller to `cd` to the repo root first
# (or otherwise be somewhere `git diff --cached` resolves against the real
# repo) — this is a warn-only tripwire, not a security boundary; it catches
# nothing sophisticated and never blocks anything by itself.
#
# Provides:
#
#   SECRET_PATTERN      common secret-shaped token regex (AWS-style access
#                       key, PEM private-key header, Slack token).
#
#   staged_secret_hits()   prints every staged ADDED line (git diff --cached,
#                       file-header lines excluded) that matches
#                       SECRET_PATTERN; prints nothing if there are none.
#                       Never fails — callers decide what "found something"
#                       means for them (doctor.sh prints OK/WARN either way;
#                       pre-commit only speaks up when there is a hit).

SECRET_PATTERN='AKIA[0-9A-Z]{16}|-----BEGIN[A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}'

staged_secret_hits() {
  git diff --cached -U0 -- . 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E "$SECRET_PATTERN" || true
}
