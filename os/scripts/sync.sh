#!/usr/bin/env bash
# sync.sh — mechanical arm of /sync: pull → commit → push, satellites first, main last.
#
# Usage: os/scripts/sync.sh "<commit message>"
#
# Per repo (each existing path in os/satellites.txt, then this repo):
#   1. git pull --ff-only — on failure print PULL BLOCKED and stop (exit 1);
#      resolve per os/playbooks/resolve-conflict.md, then rerun.
#   2. stage everything, commit only if dirty, push.
# A repo with no upstream is committed locally; pull/push are skipped with a
# note. Never force-pushes, never merges — that is a human decision (law 8).

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

MSG=${1:-}
if [ -z "$MSG" ]; then
  echo 'usage: os/scripts/sync.sh "<commit message>"' >&2
  exit 2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sync.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

SYNCED=0

sync_repo() {
  sr_path=$1
  sr_label=$2
  echo "== $sr_label"
  if ! git -C "$sr_path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "skip: $sr_label (not a git repo)"
    return 0
  fi
  if git -C "$sr_path" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    has_upstream=1
  else
    has_upstream=0
    echo "note: no upstream — pull and push skipped"
  fi
  if [ "$has_upstream" -eq 1 ]; then
    if ! git -C "$sr_path" pull --ff-only; then
      echo "PULL BLOCKED — resolve per os/playbooks/resolve-conflict.md ($sr_label)"
      exit 1
    fi
  fi
  git -C "$sr_path" add -A
  if [ -n "$(git -C "$sr_path" status --porcelain)" ]; then
    git -C "$sr_path" commit -m "$MSG"
  else
    echo "nothing to commit"
  fi
  if [ "$has_upstream" -eq 1 ]; then
    git -C "$sr_path" push
  fi
  SYNCED=$((SYNCED + 1))
}

# Satellites first, main repo last — main's pointer pages should only ever
# reference satellite states that are already pushed.
: > "$TMP/sats"
if [ -f os/satellites.txt ]; then
  # Strip comments and trim with sed — never xargs (apostrophes kill it).
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' os/satellites.txt \
    | sed '/^$/d' > "$TMP/sats"
fi
while IFS= read -r p; do
  case $p in "~/"*) p="$HOME/${p#\~/}" ;; esac
  if [ -e "$p" ]; then
    sync_repo "$p" "$p"
  else
    echo "skip: $p (missing)"
  fi
done < "$TMP/sats"
sync_repo "$ROOT" "main ($ROOT)"

echo "OK: sync complete ($SYNCED repo(s))"
