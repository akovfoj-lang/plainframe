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
#
# Protected-path gate (law 7, main repo only): a dirty CLAUDE.md, AGENTS.md,
# os/scripts/ (incl. hooks/), os/playbooks/, os/commands.md, .gitignore,
# os/satellites.txt, or an os/decisions.md change beyond append-only draft
# entries, blocks the sync. The owner enacts by rerunning with a commit
# message that has OWNER-CONFIRMED as its own line (see os/scripts/lib/guard.sh
# for the exact rule — a mention, prefix, or negation never counts) — this is
# first line of defense only; the same gate is enforced at the git level by
# os/scripts/hooks/commit-msg, so a raw `git commit` cannot bypass it (PF-003).
#
# Satellite guard (PF-006): a satellite with its own uncommitted work is never
# swept into a commit sight-unseen. If a satellite tree is dirty, this lists
# the files and skips that satellite (pull still happens; nothing is staged,
# committed, or pushed there) unless the commit message has SATELLITE-CONFIRMED
# as its own line — a separate token from OWNER-CONFIRMED on purpose, so
# approving a main-repo protected-path edit never accidentally blanket-approves
# an unrelated satellite's stray files.

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

# shellcheck source=lib/guard.sh
. "$ROOT/os/scripts/lib/guard.sh"

if owner_confirmed "$MSG"; then
  :
else
  : > "$TMP/prot"
  # shellcheck disable=SC2086
  git status --porcelain -- $PROTECTED_PATHS >> "$TMP/prot" || true
  if [ -n "$(git status --porcelain -- os/decisions.md)" ]; then
    OLD_LEDGER="$TMP/ledger-old"
    if git cat-file -e HEAD:os/decisions.md 2>/dev/null; then
      git show HEAD:os/decisions.md > "$OLD_LEDGER"
    else
      : > "$OLD_LEDGER"
    fi
    NEW_LEDGER="$TMP/ledger-new"
    if [ -f os/decisions.md ]; then
      cp os/decisions.md "$NEW_LEDGER"
    else
      : > "$NEW_LEDGER"
    fi
    if ! ledger_append_only "$OLD_LEDGER" "$NEW_LEDGER"; then
      git status --porcelain -- os/decisions.md >> "$TMP/prot"
    fi
  fi
  if [ -s "$TMP/prot" ]; then
    echo "BLOCKED: protected paths changed (law 7 — agents draft, the owner enacts):" >&2
    sed 's/^/  /' "$TMP/prot" >&2
    echo "OWNER-CONFIRMED is an owner-only token — only the owner can approve this in-session." >&2
    cat >&2 <<'EOF'
With the owner's explicit in-session yes, rerun with a commit message that has
OWNER-CONFIRMED as its own line (trimmed of surrounding whitespace) — a
mention, prefix, or negation elsewhere in the message never counts. Example:
  os/scripts/sync.sh "<commit message>
OWNER-CONFIRMED"
EOF
    exit 1
  fi
fi

SYNCED=0

sync_repo() {
  sr_path=$1
  sr_label=$2
  sr_is_satellite=$3
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
  if [ "$sr_is_satellite" -eq 1 ]; then
    sr_dirty=$(git -C "$sr_path" status --porcelain)
    if [ -n "$sr_dirty" ] && ! satellite_confirmed "$MSG"; then
      echo "ABORTED: $sr_label has uncommitted work sync has not been told to include (PF-006):" >&2
      printf '%s\n' "$sr_dirty" | sed 's/^/  /' >&2
      cat >&2 <<'EOF'
Review the files above. With the owner's explicit in-session review, rerun
with a commit message that has SATELLITE-CONFIRMED as its own line:
  os/scripts/sync.sh "<commit message>
SATELLITE-CONFIRMED"
EOF
      return 0
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
    sync_repo "$p" "$p" 1
  else
    echo "skip: $p (missing)"
  fi
done < "$TMP/sats"
sync_repo "$ROOT" "main ($ROOT)" 0

echo "OK: sync complete ($SYNCED repo(s))"
