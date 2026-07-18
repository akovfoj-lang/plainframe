#!/usr/bin/env bash
# gen-status.sh — write STATUS.md: receipts, counts, flags, git state.
#
# Usage: os/scripts/gen-status.sh          regenerate STATUS.md in place
#        os/scripts/gen-status.sh --check  exit 1 (writing nothing) if STATUS.md is stale
#
# Reports: last 10 worklog receipts · inbox count + oldest item age (days) ·
# incubator counts by "status:" line · open flags (FLAG: lines in os/roadmap.md,
# plus any decisions.md entry still "**Status:** draft" — void until confirmed, law 2) ·
# git state (branch, dirty file count, unpushed commit count).
# The dirty count excludes generated MAP.md/STATUS.md — counting the file this
# script is about to write would make --check permanently unstable.
# STATUS.md is only ever written by this script (law 6).

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

case "${1:-}" in
  ""|--check) ;;
  *) echo "usage: os/scripts/gen-status.sh [--check]" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/gen-status.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# mtime in epoch seconds — BSD stat first, GNU stat as fallback.
file_mtime() {
  if stat -f %m "$1" 2>/dev/null; then :; else stat -c %Y "$1"; fi
}

generate() {
  printf '%s\n' '<!-- GENERATED — do not hand-edit. Regenerate: os/scripts/gen-status.sh -->'
  printf '\n# STATUS\n\n'
  printf '%s\n' 'Receipts, counts, and open flags — reported, never inferred from prose (law 6).'

  # -- Last 10 receipts ------------------------------------------------------
  printf '\n## Last 10 receipts\n\n'
  : > "$TMP/receipts"
  if [ -f os/worklog.md ]; then
    grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' os/worklog.md > "$TMP/receipts" || true
  fi
  rc=$(wc -l < "$TMP/receipts"); rc=$((rc))
  if [ "$rc" -gt 0 ]; then
    tail -10 "$TMP/receipts" | sed 's/^/- /'
  else
    printf -- '- (none)\n'
  fi

  # -- Inbox -----------------------------------------------------------------
  printf '\n## Inbox\n\n'
  : > "$TMP/inbox"
  if [ -d inbox ]; then
    find inbox -type f ! -name 'README.md' ! -name '.*' > "$TMP/inbox"
  fi
  ic=$(wc -l < "$TMP/inbox"); ic=$((ic))
  printf -- '- items: %s\n' "$ic"
  if [ "$ic" -gt 0 ]; then
    now=$(date +%s)
    oldest=""
    while IFS= read -r f; do
      m=$(file_mtime "$f")
      if [ -z "$oldest" ] || [ "$m" -lt "$oldest" ]; then oldest=$m; fi
    done < "$TMP/inbox"
    printf -- '- oldest: %s day(s)\n' "$(( (now - oldest) / 86400 ))"
  else
    printf -- '- oldest: n/a\n'
  fi

  # -- Incubator -------------------------------------------------------------
  printf '\n## Incubator\n\n'
  : > "$TMP/inc"
  if [ -d incubator ]; then
    find incubator -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort > "$TMP/inc"
  fi
  nc=$(wc -l < "$TMP/inc"); nc=$((nc))
  printf -- '- items: %s\n' "$nc"
  if [ "$nc" -gt 0 ]; then
    : > "$TMP/statuses"
    while IFS= read -r f; do
      s=$(awk 'sub(/^status:[[:space:]]*/, "") { sub(/[[:space:]]+$/, ""); print; exit }' "$f")
      [ -n "$s" ] || s="(no status)"
      printf '%s\n' "$s" >> "$TMP/statuses"
    done < "$TMP/inc"
    sort "$TMP/statuses" | uniq -c \
      | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "- %s: %d\n", $0, c }'
  fi

  # -- Open flags ------------------------------------------------------------
  printf '\n## Open flags\n\n'
  : > "$TMP/flags"
  if [ -f os/roadmap.md ]; then
    grep -E '^FLAG:' os/roadmap.md > "$TMP/flags" || true
  fi
  # Draft decision entries are open flags too: an unconfirmed rule is void (law 2)
  # and must stay visible until the owner confirms or deletes it.
  : > "$TMP/drafts"
  if [ -f os/decisions.md ]; then
    awk '/^## /            { h = $0; sub(/^## /, "", h) }
         /^\*\*Status:\*\*[[:space:]]*draft/ {
           printf "DRAFT decision (void until owner confirms, law 2): %s\n", h }' \
      os/decisions.md > "$TMP/drafts"
  fi
  cat "$TMP/drafts" >> "$TMP/flags"
  fc=$(wc -l < "$TMP/flags"); fc=$((fc))
  if [ "$fc" -gt 0 ]; then
    sed 's/^/- /' "$TMP/flags"
  else
    printf -- '- (none)\n'
  fi

  # -- Git -------------------------------------------------------------------
  printf '\n## Git\n\n'
  if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="(no branch)"
    dirty=$(git status --porcelain -- ':(exclude)MAP.md' ':(exclude)STATUS.md' | wc -l)
    dirty=$((dirty))
    printf -- '- branch: %s\n' "$branch"
    printf -- '- dirty files: %s (generated MAP/STATUS excluded)\n' "$dirty"
    if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      ahead=$(git rev-list --count '@{u}..HEAD'); ahead=$((ahead))
      printf -- '- unpushed commits: %s\n' "$ahead"
    else
      printf -- '- unpushed commits: (no upstream)\n'
    fi
  else
    printf -- '- (not a git repo)\n'
  fi
}

generate > "$TMP/STATUS.md"

if [ "${1:-}" = "--check" ]; then
  if [ ! -f STATUS.md ]; then
    echo "STALE: STATUS.md is missing. Run os/scripts/gen-status.sh."
    exit 1
  fi
  if diff -u STATUS.md "$TMP/STATUS.md" > "$TMP/diff"; then
    echo "OK: STATUS.md is current"
  else
    echo "STALE: STATUS.md is out of date (current vs regenerated):"
    cat "$TMP/diff"
    echo "Run os/scripts/gen-status.sh to regenerate."
    exit 1
  fi
else
  cp "$TMP/STATUS.md" STATUS.md
  echo "OK: STATUS.md written"
fi
