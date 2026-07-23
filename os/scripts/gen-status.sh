#!/usr/bin/env bash
# gen-status.sh — write STATUS.md: receipts, counts, flags, git state.
#
# Usage: os/scripts/gen-status.sh          regenerate STATUS.md in place
#        os/scripts/gen-status.sh --check  exit 1 (writing nothing) if STATUS.md is stale
#
# Reports: last 10 worklog receipts · inbox count + oldest item age (days) ·
# incubator counts by "status:" line · open flags (FLAG: lines in os/roadmap.md,
# plus any decisions.md entry still "**Status:** draft" — void until confirmed, law 2) ·
# latest /audit report + its 🔴/🟡 flag counts, if any report exists (PF-009) ·
# git state (branch, dirty file count, unpushed commit count).
# The dirty count excludes generated MAP.md/STATUS.md — counting the file this
# script is about to write would make --check permanently unstable.
# --check ignores volatile lines (dirty files, unpushed commits, oldest age):
# they are true at generation time but drift with no repo change — a committed
# STATUS would otherwise be stale-by-construction on every clean clone.
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
trap 'rm -rf "$TMP" ".STATUS.md.$$"' EXIT

# mtime in epoch seconds — BSD stat first, GNU stat as fallback. Each probe's
# stdout is captured on its own command substitution (a GNU stat rejecting the
# BSD-style flags still prints filesystem info before it fails, and that must
# never leak into the result), and the result is validated as a plain integer
# before use — a probe that produces neither is a loud internal error, never a
# silent unbound var downstream.
file_mtime() {
  m=$(stat -f %m -- "$1" 2>/dev/null) || m=$(stat -c %Y -- "$1" 2>/dev/null) || m=""
  case "$m" in
    ''|*[!0-9]*)
      echo "internal error: cannot read mtime for $1 (stat probe failed on both BSD and GNU forms)" >&2
      return 2 ;;
  esac
  printf '%s\n' "$m"
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
  : > "$TMP/inbox0"
  if [ -d inbox ]; then
    # NUL-delimited: inbox filenames are external data — even a newline inside
    # one must not split a record or crash the count.
    find inbox -type f ! -name 'README.md' ! -name '.*' -print0 > "$TMP/inbox0"
  fi
  ic=0
  oldest=""
  while IFS= read -r -d '' f; do
    ic=$((ic + 1))
    m=$(file_mtime "$f")
    if [ -z "$oldest" ] || [ "$m" -lt "$oldest" ]; then oldest=$m; fi
  done < "$TMP/inbox0"
  printf -- '- items: %s\n' "$ic"
  if [ "$ic" -gt 0 ]; then
    now=$(date +%s)
    printf -- '- oldest: %s day(s)\n' "$(( (now - oldest) / 86400 ))"
  else
    printf -- '- oldest: n/a\n'
  fi

  # -- Incubator -------------------------------------------------------------
  printf '\n## Incubator\n\n'
  # NUL-delimited end to end: an incubator filename with an embedded newline
  # must not split into two records — a plain `find | sort` piped into a
  # newline-delimited `while read` would hand awk half a filename, which then
  # fails to open it and (under set -e) crashes gen-status outright (PF-020).
  : > "$TMP/inc0"
  if [ -d incubator ]; then
    find incubator -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print0 \
      | sort -z > "$TMP/inc0"
  fi
  nc=0
  while IFS= read -r -d '' _f; do nc=$((nc + 1)); done < "$TMP/inc0"
  printf -- '- items: %s\n' "$nc"
  if [ "$nc" -gt 0 ]; then
    : > "$TMP/statuses"
    while IFS= read -r -d '' f; do
      s=$(awk 'sub(/^status:[[:space:]]*/, "") { sub(/[[:space:]]+$/, ""); print; exit }' "$f")
      [ -n "$s" ] || s="(no status)"
      printf '%s\n' "$s" >> "$TMP/statuses"
    done < "$TMP/inc0"
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

  # -- Audit -------------------------------------------------------------------
  # Surfaces the latest /audit report and its flag counts (PF-009) — an audit
  # report is content in the tree (archive/audit-YYYY-MM-DD.md), not a git or
  # filesystem-timing fact, so unlike the Git section below this needs no
  # exclusion from --check: it is exactly as stable as any other tracked file.
  printf '\n## Audit\n\n'
  latest_audit=""
  if [ -d archive ]; then
    latest_audit=$(find archive -maxdepth 1 -type f -name 'audit-*.md' 2>/dev/null | sort | tail -n 1)
  fi
  if [ -n "$latest_audit" ]; then
    red=$(grep -cF '🔴' "$latest_audit" 2>/dev/null || true); red=$((red))
    yellow=$(grep -cF '🟡' "$latest_audit" 2>/dev/null || true); yellow=$((yellow))
    printf -- '- latest: %s\n' "$latest_audit"
    printf -- '- flags: %s red, %s yellow\n' "$red" "$yellow"
  else
    printf -- '- latest: none yet — run /audit\n'
  fi

  # -- Git -------------------------------------------------------------------
  printf '\n## Git\n\n'
  printf -- '_Snapshot from the last regen, not live — branch/dirty/unpushed below are only\n'
  printf -- 'as current as this file. Run `os/scripts/gen-status.sh` (or plain `git status`)\n'
  printf -- 'for the real-time state._\n\n'
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
    # Satellites: one line each — a stuck satellite must not rot invisibly
    # behind a clean main repo (law 8). Volatile: stripped in --check.
    if [ -f os/satellites.txt ]; then
      sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' os/satellites.txt \
        | sed '/^$/d' > "$TMP/sats"
      while IFS= read -r sp; do
        case $sp in "~/"*) sp="$HOME/${sp#\~/}" ;; esac
        if [ ! -e "$sp" ]; then
          printf -- '- satellite %s: missing\n' "$sp"
        elif ! git -C "$sp" rev-parse --git-dir >/dev/null 2>&1; then
          printf -- '- satellite %s: not a git repo\n' "$sp"
        else
          sd=$(git -C "$sp" status --porcelain | wc -l); sd=$((sd))
          if git -C "$sp" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
            sa=$(git -C "$sp" rev-list --count '@{u}..HEAD'); sa=$((sa))
          else
            sa="(no upstream)"
          fi
          printf -- '- satellite %s: dirty %s, unpushed %s\n' "$sp" "$sd" "$sa"
        fi
      done < "$TMP/sats"
    fi
  else
    printf -- '- (not a git repo)\n'
  fi
}

generate > "$TMP/STATUS.md"

# Drop lines that drift with no repo change — see header. Never used when writing.
# `branch` joined dirty/unpushed/oldest/satellite here (MAJOR 4): switching
# branches must not block every commit until a regen nobody asked for.
# `(not a git repo)` is here too — not because it drifts on a real clone,
# but because the pre-commit hook validates the STAGED INDEX by exporting it
# to a plain, non-git temp directory (PF-002) and running this script
# against that export; git genuinely is unavailable there, which is a fact
# about the checking environment, not about repo content, so it must never
# read as staleness.
strip_volatile() {
  grep -vE '^- (dirty files|unpushed commits|oldest|branch):|^- satellite |^- \(not a git repo\)$' "$1" || true
}

if [ "${1:-}" = "--check" ]; then
  if [ ! -f STATUS.md ]; then
    echo "STALE: STATUS.md is missing. Run os/scripts/gen-status.sh."
    exit 1
  fi
  strip_volatile STATUS.md > "$TMP/cur"
  strip_volatile "$TMP/STATUS.md" > "$TMP/new"
  if diff -u "$TMP/cur" "$TMP/new" > "$TMP/diff"; then
    echo "OK: STATUS.md is current"
  else
    echo "STALE: STATUS.md is out of date (current vs regenerated, volatile lines ignored):"
    cat "$TMP/diff"
    echo "Run os/scripts/gen-status.sh to regenerate."
    exit 1
  fi
else
  # Temp sibling + mv: a failure mid-write must never leave a truncated STATUS.
  NEW=".STATUS.md.$$"
  cp "$TMP/STATUS.md" "$NEW"
  mv "$NEW" STATUS.md
  echo "OK: STATUS.md written"
fi
