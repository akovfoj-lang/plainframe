#!/usr/bin/env bash
# gen-map.sh — write MAP.md, the routing table: one line per home.
#
# Usage: os/scripts/gen-map.sh          regenerate MAP.md in place
#        os/scripts/gen-map.sh --check  exit 1 (writing nothing) if MAP.md is stale
#
# A home's one-line description is the first non-empty line after the H1 in its
# README.md — "(no README)" if the file is absent. Root files use their own H1.
# archive/ is always a single line; areas/ also lists each area one level deep.
# os/ lists its core kernel files (ledger, roadmap, routine, worklog, commands) —
# law 1 says agents reach pages only through MAP, so the ledger law 2 elevates
# above everything must be routable from here.
# Output is deterministic (LC_ALL=C, stable glob order).
# MAP.md is only ever written by this script (law 6).

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

case "${1:-}" in
  ""|--check) ;;
  *) echo "usage: os/scripts/gen-map.sh [--check]" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/gen-map.XXXXXX")
trap 'rm -rf "$TMP" ".MAP.md.$$"' EXIT

# First non-empty line after the first H1; prints nothing if there is none.
readme_desc() {
  awk 'seen && NF { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print; exit }
       /^# / { seen = 1 }' "$1"
}

# The H1 text of a file; prints nothing if there is none.
file_h1() {
  awk '/^# / { sub(/^#[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

# True if the given path is gitignored (or simply untracked-and-ignorable) —
# a deterministic MAP must not depend on ignored build/install artifacts that
# differ machine to machine (e.g. node_modules/). Safe outside a git repo or
# when git is unavailable: git-check-ignore's failure there is treated as
# "not ignored", which just falls back to the pre-existing behavior.
is_ignored() {
  git check-ignore -q -- "$1" 2>/dev/null
}

# Print "- <dir>/ — <desc>" for one home directory.
home_line() {
  hl_dir=$1
  hl_indent=$2
  if [ -f "$hl_dir/README.md" ]; then
    hl_desc=$(readme_desc "$hl_dir/README.md")
    [ -n "$hl_desc" ] || hl_desc="(no description)"
  else
    hl_desc="(no README)"
  fi
  printf -- '%s- %s/ — %s\n' "$hl_indent" "$hl_dir" "$hl_desc"
}

generate() {
  printf '%s\n' '<!-- GENERATED — do not hand-edit. Regenerate: os/scripts/gen-map.sh -->'
  printf '\n# MAP\n\n'
  printf '%s\n' 'One line per home. Route from here; never scan the repo for relevance (law 1).'
  printf '\n## Root files\n\n'
  for f in AGENTS.md CLAUDE.md README.md; do
    if [ -f "$f" ]; then
      t=$(file_h1 "$f")
      [ -n "$t" ] || t="(no title)"
      printf -- '- %s — %s\n' "$f" "$t"
    fi
  done
  printf '\n## Homes\n\n'
  for d in */; do
    [ -d "$d" ] || continue
    d=${d%/}
    is_ignored "$d" && continue
    home_line "$d" ""
    # areas/ lists each area; archive/ (and everything else) stays one line.
    if [ "$d" = "areas" ]; then
      for s in areas/*/; do
        [ -d "$s" ] || continue
        s=${s%/}
        is_ignored "$s" && continue
        home_line "$s" "  "
      done
    fi
    # os/ lists the kernel core files so law 1 can actually reach them.
    if [ "$d" = "os" ]; then
      for kf in os/commands.md os/decisions.md os/roadmap.md os/routine.md os/worklog.md; do
        [ -f "$kf" ] || continue
        kt=$(file_h1 "$kf")
        [ -n "$kt" ] || kt="(no title)"
        printf -- '  - %s — %s\n' "$kf" "$kt"
      done
    fi
  done
}

generate > "$TMP/MAP.md"

# Soft token budget: MAP is read in full every session — growth here is boot
# cost for every future session. Warn, never fail.
words=$(wc -w < "$TMP/MAP.md"); words=$((words))
if [ "$words" -gt 350 ]; then
  echo "WARN: MAP.md is $words words (soft budget 350) — tighten descriptions or archive finished areas" >&2
fi

if [ "${1:-}" = "--check" ]; then
  if [ ! -f MAP.md ]; then
    echo "STALE: MAP.md is missing. Run os/scripts/gen-map.sh."
    exit 1
  fi
  if diff -u MAP.md "$TMP/MAP.md" > "$TMP/diff"; then
    echo "OK: MAP.md is current"
  else
    echo "STALE: MAP.md is out of date (current vs regenerated):"
    cat "$TMP/diff"
    echo "Run os/scripts/gen-map.sh to regenerate."
    exit 1
  fi
else
  # Temp sibling + mv: a failure mid-write must never leave a truncated MAP.
  NEW=".MAP.md.$$"
  cp "$TMP/MAP.md" "$NEW"
  mv "$NEW" MAP.md
  echo "OK: MAP.md written"
fi
