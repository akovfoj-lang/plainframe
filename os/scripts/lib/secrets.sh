# shellcheck shell=bash
# secrets.sh — the staged-secrets check (PF-014, PF-035), shared by
# os/scripts/doctor.sh and os/scripts/hooks/pre-commit so the rules live in
# one place and the two call sites can never drift apart (law 3).
#
# Sourced, not executed. Requires the caller to `cd` to the repo root first
# (or otherwise be somewhere `git diff --cached` resolves against the real
# repo).
#
# Two layers, because history can never be rewritten here (Never tier): a key
# that lands in a commit stays in it, so prevention is the only real fix.
#
#   gitleaks (https://github.com/gitleaks/gitleaks), when it is installed, is
#   the real scanner: hundreds of provider rules, values always redacted. A
#   hit BLOCKS the commit. Set PLAINFRAME_GITLEAKS=off to skip it for one
#   command (the test suite does, to exercise the fallback).
#
#   SECRET_PATTERN is the fallback when gitleaks is absent: a grep for the key
#   shapes an owner of this template is most likely to paste — AWS access
#   keys, PEM private-key headers, Slack, Anthropic, OpenAI, GitHub and Google
#   API keys. It only warns: a regex this simple misfires too easily to block.
#
# Provides:
#
#   SECRET_PATTERN          the fallback regex (ERE).
#   secrets_scanner         prints "gitleaks" when the real scanner will run,
#                           "pattern" otherwise.
#   staged_secret_scan      runs gitleaks over exactly what is staged, values
#                           redacted; exit 1 and a report on stdout when it
#                           finds something, 0 when clean.
#   staged_secret_hits      prints every staged ADDED line (git diff --cached,
#                           file-header lines excluded) that matches
#                           SECRET_PATTERN; prints nothing if there are none.
#                           Never fails.

SECRET_PATTERN='AKIA[0-9A-Z]{16}|-----BEGIN[A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{32,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|AIza[0-9A-Za-z_-]{35}'

secrets_scanner() {
  if [ "${PLAINFRAME_GITLEAKS:-on}" != off ] && command -v gitleaks >/dev/null 2>&1; then
    echo gitleaks
  else
    echo pattern
  fi
}

staged_secret_scan() {
  gitleaks git --pre-commit --staged --redact --no-banner --no-color -v . 2>&1
}

staged_secret_hits() {
  git diff --cached -U0 -- . 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -E "$SECRET_PATTERN" || true
}
