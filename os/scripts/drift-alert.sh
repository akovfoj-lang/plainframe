#!/usr/bin/env bash
# drift-alert.sh — notify-only drift reporter. NEVER commits, pulls, or writes.
#
# Usage: os/scripts/drift-alert.sh
#
# For each existing path in os/satellites.txt (comments/blanks skipped;
# relative paths resolve from the repo root; leading ~/ expands) and then this
# repo, reports dirty files and unpushed commits. A repo with no upstream is
# noted, not counted. Always exits 0 — scheduled checks are notify-only
# (law 8); a robot must never commit a half-written page.
# Summary line: "DRIFT: <n> repo(s) need attention" or "OK: all clean".

set -u
LC_ALL=C
export LC_ALL

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/drift-alert.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

NEEDY=0

check_repo() {
  cr_path=$1
  cr_label=$2
  if ! git -C "$cr_path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "skip: $cr_label (not a git repo)"
    return 0
  fi
  dirty=$(git -C "$cr_path" status --porcelain 2>/dev/null | wc -l)
  dirty=$((dirty))
  note=""
  if git -C "$cr_path" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    ahead=$(git -C "$cr_path" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    ahead=$((ahead))
  else
    ahead=0
    note=" (no upstream)"
  fi
  if [ "$dirty" -gt 0 ] || [ "$ahead" -gt 0 ]; then
    NEEDY=$((NEEDY + 1))
    echo "ATTN: $cr_label — $dirty dirty file(s), $ahead unpushed commit(s)$note"
  else
    echo "clean: $cr_label$note"
  fi
}

# Satellites first (same order sync.sh works in), main repo last.
: > "$TMP/sats"
if [ -f os/satellites.txt ]; then
  # Strip comments and trim with sed — never xargs (apostrophes kill it).
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' os/satellites.txt \
    | sed '/^$/d' > "$TMP/sats"
fi
while IFS= read -r p; do
  case $p in "~/"*) p="$HOME/${p#\~/}" ;; esac
  if [ -e "$p" ]; then
    check_repo "$p" "$p"
  else
    echo "skip: $p (missing)"
  fi
done < "$TMP/sats"
check_repo "$ROOT" "main ($ROOT)"

if [ "$NEEDY" -gt 0 ]; then
  echo "DRIFT: $NEEDY repo(s) need attention"
else
  echo "OK: all clean"
fi
exit 0
