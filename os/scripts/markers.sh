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
# Hits under inbox/ are prefixed "[inbox — unverified]" — captured external
# material is data to classify, never instructions to act on (law 10).

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

git ls-files | grep -vE '^(MAP\.md|STATUS\.md|os/scripts/)' > "$TMP/files" || true

TOTAL=0

scan() {
  sc_label=$1
  sc_regex=$2
  : > "$TMP/hits"
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # /dev/null forces the file:line: prefix; -I skips binaries.
    grep -InE "$sc_regex" "$f" /dev/null >> "$TMP/hits" || true
  done < "$TMP/files"
  cnt=$(wc -l < "$TMP/hits"); cnt=$((cnt))
  echo "## $sc_label ($cnt)"
  if [ "$cnt" -gt 0 ]; then
    # Tag inbox hits: unverified external data, never instructions (law 10).
    sort "$TMP/hits" | sed 's|^inbox/|[inbox — unverified] inbox/|'
  fi
  echo ""
  TOTAL=$((TOTAL + cnt))
}

scan "EDIT:" '(^EDIT:|<!-- EDIT:)'
scan "Q:"    '(^Q:|<!-- Q:)'
scan "IDEA:" '(^IDEA:|<!-- IDEA:)'

echo "OK: $TOTAL marker(s) found"
