#!/usr/bin/env bash
# markers.sh — list EDIT: / Q: / IDEA: markers in tracked files.
#
# Usage: os/scripts/markers.sh
#
# Scans git-tracked files only, excluding MAP.md, STATUS.md, and os/scripts/
# (.git is never tracked). Used by /sweep beat 1.
# Patterns — kept simple on purpose:
#   All three markers count only at line start or after "<!-- ".
#   (Anchoring avoids false hits like "FAQ:" and prose that merely MENTIONS a marker.)
# Prints file:line:text grouped by marker type, then a summary count.
# Hits are prefixed "[untrusted origin]" when the hit's file is unverified
# external material (law 10): anything under inbox/, OR anything anywhere
# else that still carries the ingest/sweep provenance envelope (a literal
# "trust: data" line — see os/playbooks/ingest.md). Tagging by envelope
# presence, not just the inbox/ path, means routed content keeps showing
# its untrusted origin after /sweep or /ingest moves it out of inbox/
# (PF-007) — the envelope is defined to travel with the content precisely
# so this check still finds it.

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repo — markers.sh scans tracked files only" >&2
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/markers.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# NUL-delimited: a filename with a newline in it must not split into two paths.
git ls-files -z > "$TMP/files0"

# Precompute which files are "unverified" (PF-007): anything under inbox/,
# or anything anywhere that still carries a literal "trust: data" envelope
# line (bare, or HTML-comment-wrapped — same two shapes the marker patterns
# below accept). One pass up front, keyed on the same newline-sanitized path
# used everywhere else here, so scan() can do a cheap membership check per
# hit instead of re-deriving taint from a path prefix that routing breaks.
: > "$TMP/unverified"
while IFS= read -r -d '' f; do
  case $f in MAP.md|STATUS.md|os/scripts/*) continue ;; esac
  [ -f "$f" ] || continue
  f_safe=$(printf '%s' "$f" | tr '\n' ' ')
  case $f in
    inbox/*) printf '%s\n' "$f_safe" >> "$TMP/unverified" ;;
    *)
      if grep -qE '(^trust:[[:space:]]*data[[:space:]]*$|<!--[[:space:]]*trust:[[:space:]]*data[[:space:]]*-->)' -- "$f" 2>/dev/null; then
        printf '%s\n' "$f_safe" >> "$TMP/unverified"
      fi
      ;;
  esac
done < "$TMP/files0"

TOTAL=0

scan() {
  sc_label=$1
  sc_regex=$2
  : > "$TMP/hits"
  while IFS= read -r -d '' f; do
    case $f in MAP.md|STATUS.md|os/scripts/*) continue ;; esac
    [ -f "$f" ] || continue
    # A filename with an embedded newline is one NUL-delimited record here,
    # but grep's own "file:line:text" prefix would print that raw filename
    # verbatim — splitting one hit across two physical lines in $TMP/hits and
    # double-counting it downstream (wc -l counts newlines, not hits) (PF-020).
    # -h drops grep's own filename prefix; we prepend a newline-sanitized one
    # ourselves. -I skips binaries; -- ends option parsing so a file named
    # "-something.md" is data, not flags.
    f_safe=$(printf '%s' "$f" | tr '\n' ' ')
    if grep -hInE "$sc_regex" -- "$f" 2>/dev/null \
        | while IFS= read -r hitline; do printf '%s:%s\n' "$f_safe" "$hitline"; done \
        >> "$TMP/hits"
    then :; fi
  done < "$TMP/files0"
  cnt=$(wc -l < "$TMP/hits"); cnt=$((cnt))
  echo "## $sc_label ($cnt)"
  if [ "$cnt" -gt 0 ]; then
    # Tag by envelope presence, not path (PF-007): a hit's path (everything
    # before the first ":") is looked up in the unverified set built above.
    sort "$TMP/hits" | while IFS= read -r hitline; do
      hp=${hitline%%:*}
      if grep -qxF "$hp" "$TMP/unverified" 2>/dev/null; then
        printf '[untrusted origin] %s\n' "$hitline"
      else
        printf '%s\n' "$hitline"
      fi
    done
  fi
  echo ""
  TOTAL=$((TOTAL + cnt))
}

scan "EDIT:" '(^EDIT:|<!-- EDIT:)'
scan "Q:"    '(^Q:|<!-- Q:)'
scan "IDEA:" '(^IDEA:|<!-- IDEA:)'

echo "OK: $TOTAL marker(s) found"
