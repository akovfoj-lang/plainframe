#!/usr/bin/env bash
# gen-status.sh — write STATUS.md: counts and open flags.
#
# Usage: os/scripts/gen-status.sh          regenerate STATUS.md in place
#        os/scripts/gen-status.sh --check  exit 1 (writing nothing) if STATUS.md is stale
#
# Reports: inbox count + oldest item age (days, from each item's "captured-at:"
# line, file time only as a fallback — PF-028) · incubator counts by "status:"
# line · workspace counts by "status:" line · answers count · open flags
# (FLAG: lines in os/roadmap.md, plus any decisions.md entry still
# "**Status:** draft" — void until confirmed, law 2, plus any dated worklog
# line that misses the receipt shape — PF-027) · latest /audit report + its
# 🔴/🟡 flag counts, one per check heading, if any report exists (PF-009,
# PF-026).
# No receipts and no git state: either one changed STATUS in every commit
# (481 of 481 in one review), for facts that live elsewhere. The newest
# receipts are in session-start.sh's report, all of them in os/worklog.md;
# the live git state is in that report too, and in `git status`.
# --check ignores the one volatile line (the oldest inbox item's age): it is
# true at generation time but drifts with no repo change — a committed STATUS
# would otherwise be stale-by-construction on every clean clone.
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

# file_mtime (BSD stat first, GNU as fallback, validated) lives in lib/fs.sh,
# shared with gen-desk.sh and session-start.sh (law 3).
# shellcheck source=lib/fs.sh
. "$ROOT/os/scripts/lib/fs.sh"

# git_files0 DIR — NUL-delimited files under DIR that git would store
# (tracked, or untracked and not ignored). Outside a repo — pre-commit checks
# an export of the index — every file there is one.
git_files0() {
  if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
    git ls-files -z --cached --others --exclude-standard -- "$1"
  else
    find "$1" -type f -print0
  fi
}

# top_md0 DIR — DIR's own pages (*.md, not README.md, not in a subfolder),
# NUL-delimited and sorted.
top_md0() {
  git_files0 "$1" | while IFS= read -r -d '' f; do
    case $f in "$1"/*/*|"$1"/README.md) continue ;; "$1"/*.md) [ -e "$f" ] && printf '%s\0' "$f" ;; esac
  done | sort -z
}

# An inbox item's capture date from its envelope (`captured-at: YYYY-MM-DD`,
# os/playbooks/ingest.md; the HTML-comment form is accepted too), as epoch
# seconds at local midnight — BSD date first, GNU date as fallback, validated
# like file_mtime above. Returns 1 when the item carries no readable date.
# File time is only the fallback (PF-028): a clone, checkout or copy rewrites
# mtimes, so an old capture reads as new on exactly the fresh clones where the
# audit's inbox-age check is run. Only the first 64 KiB is read — envelopes sit
# at the top, and an inbox item can be a large binary.
captured_at() {
  d=$(head -c 65536 "$1" 2>/dev/null \
    | grep -a -m 1 -E '^[[:space:]]*(<!--[[:space:]]*)?captured-at:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    | sed -E 's/.*captured-at:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/') || return 1
  [ -n "$d" ] || return 1
  e=$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null) \
    || e=$(date -d "$d 00:00:00" +%s 2>/dev/null) || e=""
  case "$e" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$e"
}

generate() {
  printf '%s\n' '<!-- GENERATED — do not hand-edit. Regenerate: os/scripts/gen-status.sh -->'
  printf '\n# STATUS\n\n'
  printf '%s\n' 'Counts and open flags — reported, never inferred from prose (law 6). The newest'
  printf '%s\n' 'receipts are in the session-start report; all of them are in os/worklog.md.'
  # -- Inbox -----------------------------------------------------------------
  printf '\n## Inbox\n\n'
  : > "$TMP/inbox0"
  if [ -d inbox ]; then
    # NUL-delimited: inbox filenames are external data — even a newline inside
    # one must not split a record or crash the count.
    # Only what git would store: an ignored file (Obsidian's .trash/, a
    # *.local.* scratch file) exists on one machine only, and a count that
    # includes it makes --check differ by machine.
    git_files0 inbox | while IFS= read -r -d '' f; do
      case /$f in */.*|*/README.md) continue ;; esac
      [ -e "$f" ] && printf '%s\0' "$f"
    done > "$TMP/inbox0"
  fi
  ic=0
  oldest=""
  while IFS= read -r -d '' f; do
    ic=$((ic + 1))
    m=$(captured_at "$f") || m=$(file_mtime "$f")
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
    top_md0 incubator > "$TMP/inc0"
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

  # -- Workspace -------------------------------------------------------------
  printf '\n## Workspace\n\n'
  # Same NUL-delimited discipline as Incubator above, and for the same reason
  # (PF-020): a filename with an embedded newline must stay one record.
  : > "$TMP/wsp0"
  if [ -d workspace ]; then
    top_md0 workspace > "$TMP/wsp0"
  fi
  nw=0
  while IFS= read -r -d '' _f; do nw=$((nw + 1)); done < "$TMP/wsp0"
  printf -- '- items: %s\n' "$nw"
  if [ "$nw" -gt 0 ]; then
    : > "$TMP/wstatuses"
    while IFS= read -r -d '' f; do
      s=$(awk 'sub(/^status:[[:space:]]*/, "") { sub(/[[:space:]]+$/, ""); print; exit }' "$f")
      [ -n "$s" ] || s="(no status)"
      printf '%s\n' "$s" >> "$TMP/wstatuses"
    done < "$TMP/wsp0"
    sort "$TMP/wstatuses" | uniq -c \
      | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "- %s: %d\n", $0, c }'
  fi

  # -- Answers ---------------------------------------------------------------
  printf '\n## Answers\n\n'
  na=0
  if [ -d answers ]; then
    : > "$TMP/ans0"
    top_md0 answers > "$TMP/ans0"
    while IFS= read -r -d '' _f; do na=$((na + 1)); done < "$TMP/ans0"
  fi
  printf -- '- items: %s\n' "$na"

  # -- Open flags ------------------------------------------------------------
  printf '\n## Open flags\n\n'
  : > "$TMP/flags"
  if [ -f os/roadmap.md ]; then
    open_flags os/roadmap.md > "$TMP/flags"
  fi
  # Draft decision entries are open flags too: an unconfirmed rule is void (law 2)
  # and must stay visible until the owner confirms or deletes it.
  : > "$TMP/drafts"
  if [ -f os/decisions.md ]; then
    draft_decisions os/decisions.md \
      | sed 's/^/DRAFT decision (void until owner confirms, law 2): /' > "$TMP/drafts"
  fi
  cat "$TMP/drafts" >> "$TMP/flags"
  # A dated worklog line that misses the column-0 receipt shape — bulleted or
  # indented — is invisible to every reader of receipts, so it silently fell
  # out of view (PF-027). It is surfaced here as an open flag rather than
  # failing --check: a mis-shaped record is something to straighten, not a
  # reason to block every commit.
  if [ -f os/worklog.md ]; then
    awk '/^[[:space:]]*([-*+][[:space:]]+)?[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ &&
         !/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
           d = $0; sub(/^[^0-9]*/, "", d)
           printf "MALFORMED receipt at os/worklog.md:%d (dated %s): not at column 0, so it does not read as a receipt (law 9)\n", NR, substr(d, 1, 10) }' \
      os/worklog.md >> "$TMP/flags"
  fi
  fc=$(wc -l < "$TMP/flags"); fc=$((fc))
  if [ "$fc" -gt 0 ]; then
    sed 's/^/- /' "$TMP/flags"
  else
    printf -- '- (none)\n'
  fi

  # -- Audit -------------------------------------------------------------------
  # Surfaces the latest /audit report and its flag counts (PF-009) — an audit
  # report is content in the tree (archive/audit-YYYY-MM-DD.md), not a git or
  # filesystem-timing fact, so it needs no exclusion from --check: it is
  # exactly as stable as any other tracked file.
  printf '\n## Audit\n\n'
  latest_audit=""
  if [ -d archive ]; then
    # Sorted without ".md": a second report of the day, audit-DATE-2.md,
    # must rank after audit-DATE.md ("-" sorts before ".").
    latest_audit=$(find archive -maxdepth 1 -type f -name 'audit-*.md' 2>/dev/null | sed 's/\.md$//' | sort | tail -n 1)
    [ -z "$latest_audit" ] || latest_audit="$latest_audit.md"
  fi
  if [ -n "$latest_audit" ]; then
    # One verdict per check, read from section headings only (PF-026):
    # audit.md puts each check's mark in that check's heading. Counting every
    # line that merely contained an emoji let a summary line or a quoted
    # example inflate the totals — a 1-red/4-yellow report once read as
    # 3 red, 6 yellow. A heading carrying more than one mark counts once, as
    # its worst. A report with no marked heading says so instead of reading
    # as a clean 0/0.
    read -r red yellow green <<EOF
$(awk '/^##+[[:space:]]/ {
         if (index($0, "🔴")) r++
         else if (index($0, "🟡")) y++
         else if (index($0, "🟢")) g++
       }
       END { printf "%d %d %d\n", r, y, g }' "$latest_audit")
EOF
    printf -- '- latest: %s\n' "$latest_audit"
    if [ $((red + yellow + green)) -gt 0 ]; then
      printf -- '- flags: %s red, %s yellow\n' "$red" "$yellow"
    else
      printf -- '- flags: unreadable — no section heading carries a 🟢/🟡/🔴 verdict (os/playbooks/audit.md step 1)\n'
    fi
  else
    printf -- '- latest: none yet — run /audit\n'
  fi
}

generate > "$TMP/STATUS.md"

# Drop the line that drifts with no repo change — see header. Never used when
# writing.
strip_volatile() {
  grep -vE '^- oldest:' "$1" || true
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
