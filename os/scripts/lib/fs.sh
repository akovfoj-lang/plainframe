# shellcheck shell=bash
# fs.sh — file-time helpers that work on macOS (BSD) and Linux (GNU) alike,
# shared by gen-status.sh, gen-desk.sh and session-start.sh (law 3).
#
# Sourced, not executed. Provides:
#
#   file_mtime PATH       mtime in epoch seconds — BSD stat first, GNU stat as
#                         fallback. Each probe's stdout is captured on its own
#                         command substitution (a GNU stat rejecting the
#                         BSD-style flags still prints filesystem info before
#                         it fails, and that must never leak into the result),
#                         and the result is validated as a plain integer — a
#                         probe that produces neither is a loud internal error
#                         (return 2), never a silent unbound var downstream.
#
#   epoch_date EPOCH      YYYY-MM-DD in local time — BSD `date -r` first, GNU
#                         `date -d @` as fallback.
#
#   oldest_dirty REPO     "<count> <oldest-epoch>" for the uncommitted files
#                         in REPO (untracked included, deleted files counted
#                         but not dated), or nothing when the tree is clean.
#                         Extra arguments are paths to leave out.
#
#   satellite_list        the repo paths in os/satellites.txt (read from the
#                         current directory, the repo root), one per line, for
#                         every script that walks the satellites: comment
#                         lines, " #" comments and blanks dropped, ends
#                         trimmed, a leading ~/ expanded. A "#" inside a path
#                         is part of the path.

file_mtime() {
  m=$(stat -f %m -- "$1" 2>/dev/null) || m=$(stat -c %Y -- "$1" 2>/dev/null) || m=""
  case "$m" in
    ''|*[!0-9]*)
      echo "internal error: cannot read mtime for $1 (stat probe failed on both BSD and GNU forms)" >&2
      return 2 ;;
  esac
  printf '%s\n' "$m"
}

epoch_date() {
  date -r "$1" +%Y-%m-%d 2>/dev/null || date -d "@$1" +%Y-%m-%d 2>/dev/null
}

oldest_dirty() {
  od_repo=$1; shift
  od_count=0
  od_oldest=""
  # porcelain v1 -z: "XY path\0", plus a second "\0old-path" record after a
  # rename or copy — skipped by remembering that the next record is one.
  od_skip=0
  while IFS= read -r -d '' od_rec; do
    if [ "$od_skip" -eq 1 ]; then od_skip=0; continue; fi
    od_xy=${od_rec%"${od_rec#??}"}
    od_path=${od_rec#???}
    case $od_xy in R*|C*) od_skip=1 ;; esac
    od_keep=1
    for od_ex in "$@"; do [ "$od_path" = "$od_ex" ] && od_keep=0; done
    [ "$od_keep" -eq 1 ] || continue
    od_count=$((od_count + 1))
    if [ -e "$od_repo/$od_path" ]; then
      od_m=$(file_mtime "$od_repo/$od_path") || continue
      if [ -z "$od_oldest" ] || [ "$od_m" -lt "$od_oldest" ]; then od_oldest=$od_m; fi
    fi
  done < <(git -C "$od_repo" status --porcelain=v1 -uall -z 2>/dev/null)
  [ "$od_count" -gt 0 ] || return 0
  # A deletion has no file left to date; the last commit bounds it from
  # below, so a satellite whose only dirt is deletions still ages out.
  [ -n "$od_oldest" ] || od_oldest=$(git -C "$od_repo" log -1 --format=%ct 2>/dev/null)
  printf '%s %s\n' "$od_count" "${od_oldest:-0}"
}

satellite_list() {
  [ -f os/satellites.txt ] || return 0
  # sed, never xargs (apostrophes kill it).
  sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    os/satellites.txt | sed '/^$/d' | while IFS= read -r sl_p || [ -n "$sl_p" ]; do
      # shellcheck disable=SC2088  # matching a literal "~/" prefix, not expanding it
      case $sl_p in "~/"*) sl_p="$HOME/${sl_p#\~/}" ;; esac
      printf '%s\n' "$sl_p"
    done
}

# draft_decisions FILE — prints the heading of each ledger entry whose Status
# line says draft, in any spelling ("Status: draft", "**Status**: Draft", ...)
# but never "drafted ...": a void entry must stay visible (law 2), and STATUS
# and DESK must agree on which entries are void (law 3).
draft_decisions() {
  awk '/^## / { h = $0; sub(/^## /, "", h); sub(/\r$/, "", h) }
       { l = tolower($0); sub(/\r$/, "", l) }
       l ~ /^[[:space:]>*_]*status[[:space:]*_]*:[[:space:]*_]*draft([^a-z]|$)/ { print h }' "$1"
}

# open_flags FILE — prints each "FLAG:" line of FILE, bulleted or indented as
# the owner types it, never one shown inside a code fence; each printed from
# "FLAG:" on.
open_flags() {
  awk '/^[[:space:]]*(```|~~~)/ { f = !f; next }
       f { next }
       /^[[:space:]]*([-*+>][[:space:]]*|[0-9]+[.)][[:space:]]+)*FLAG:/ {
         sub(/\r$/, ""); sub(/^[^F]*/, ""); print }' "$1"
}
