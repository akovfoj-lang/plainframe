#!/usr/bin/env bash
# session-start.sh — the start of every session, done by the machine (law 8).
#
# Usage: os/scripts/session-start.sh
#
# Claude Code runs this by itself at startup (.claude/settings.json, the
# SessionStart hook) and hands the agent its report before the first word;
# any other agent runs it as its first command (AGENTS.md). It replaces the
# hand-typed `git pull`, which an agent could not do before reading CLAUDE.md
# in a tool that loads CLAUDE.md for it (PF-039).
#
#   1. Brings GitHub's side down: fetch, then fast-forward; or, when both
#      sides moved and this tree is clean, rebase this machine's own unpushed
#      commits on top (the same rules as sync.sh, lib/converge.sh). A dirty
#      tree is never stashed, reset or rebased — it may be another session's
#      work in flight. Never commits, never pushes.
#   2. Says so when CLAUDE.md or AGENTS.md changed underneath you: re-read.
#   3. Lists the newest receipts: what happened lately, in this session or
#      another one.
#   4. Names uncommitted or unpushed work — here (with its age: another
#      session's, or something left behind) and in each satellite.
#   5. Reminds the session that it syncs itself.
#
# It does not check the generated views. sync.sh regenerates them in every
# commit, pre-commit refuses a stale one, and CI checks them again; the four
# --check runs here took about 2 s of every start and caught nothing those
# three miss.
#
# Always exits 0: a session must be able to start with the network down.

set -u
LC_ALL=C
export LC_ALL

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || { echo "session-start: not a git repo — nothing to pull"; exit 0; }

# shellcheck source=lib/converge.sh
. "$ROOT/os/scripts/lib/converge.sh"
# shellcheck source=lib/fs.sh
. "$ROOT/os/scripts/lib/fs.sh"

out() { printf -- '- %s\n' "$1"; }
echo "Session start (os/scripts/session-start.sh):"

hash_of() { git hash-object -- "$1" 2>/dev/null || echo none; }
before_claude=$(hash_of CLAUDE.md)
before_agents=$(hash_of AGENTS.md)

branch=$(git symbolic-ref -q --short HEAD || true)
op=$(unfinished_op "$ROOT")
if [ -n "$op" ]; then
  out "a $op is in progress — nothing pulled; finish or abort it first (os/playbooks/resolve-conflict.md)"
elif [ -z "$branch" ]; then
  out "detached HEAD — nothing pulled; check out a branch before syncing"
else
  up=$(upstream_of "$ROOT" "$branch")
  if [ -z "$up" ]; then
    out "$branch has no upstream — nothing to pull"
  elif ! quiet_fetch "$ROOT" "${up%% *}"; then
    out "could not reach ${up%% *} (offline?) — working from the local copy; sync.sh catches up later"
  else
    mref=${up#* }
    rtrack="refs/remotes/${up%% *}/${mref#refs/heads/}"
    u=$(git rev-parse -q --verify "$rtrack" || true)
    h=$(git rev-parse HEAD)
    if [ -z "$u" ]; then
      out "${up%% *} no longer has ${mref#refs/heads/} — nothing pulled; the commits here are on no remote until sync.sh pushes them"
    elif [ "$u" = "$h" ]; then
      out "up to date with ${up%% *}"
    elif git merge-base --is-ancestor "$h" "$u"; then
      n=$(git rev-list --count "$h..$u")
      # A file that arrives tracked but sits here untracked and ignored would
      # be overwritten without a word: git treats ignored files as expendable.
      clash=$(git diff --name-only --diff-filter=A "$h" "$u" | while IFS= read -r p; do
        if [ -e "$p" ] && git check-ignore -q --no-index -- "$p"; then printf '%s ' "$p"; fi
      done)
      if [ -n "$clash" ]; then
        out "${up%% *} is $n commit(s) ahead and adds file(s) that exist here untracked and ignored: $clash— not pulled; move them aside, then run sync.sh"
      elif git merge -q --ff-only "$u" >/dev/null 2>&1; then
        out "pulled $n commit(s) from ${up%% *} ($(git rev-parse --short "$h") → $(git rev-parse --short "$u"))"
      else
        out "${up%% *} is $n commit(s) ahead, but uncommitted edits here overlap them — not pulled; sync.sh brings them in once those are committed"
      fi
    elif git merge-base --is-ancestor "$u" "$h"; then
      out "$(git rev-list --count "$u..$h") unpushed commit(s) here — sync.sh pushes them"
    elif [ -z "$(git status --porcelain)" ]; then
      if rebase_onto "$ROOT" "$u"; then
        out "both sides had moved: rebased this machine's unpushed commit(s) onto ${up%% *} — run sync.sh to push them"
      else
        out "PULL BLOCKED: both sides had moved and these conflict: $(printf '%s ' $CONVERGE_CONFLICTS)— nothing changed; resolve per os/playbooks/resolve-conflict.md"
      fi
    else
      out "both sides have moved and this tree has uncommitted edits — not touched; sync.sh rebases once your work is committed"
    fi
  fi
fi

[ "$(hash_of CLAUDE.md)" = "$before_claude" ] || out "CLAUDE.md changed in that pull — re-read it in full before continuing (law 8)"
[ "$(hash_of AGENTS.md)" = "$before_agents" ] || out "AGENTS.md changed in that pull — re-read it too"

# A receipt is "YYYY-MM-DD <topic>: <summary>" at column 0, never inside a
# code fence: a date that merely opens a sentence is prose, not a receipt.
# Each is cut to 160 characters on a word boundary (PF-038); the whole line
# is one grep away in os/worklog.md.
if [ -f os/worklog.md ]; then
  rec=$(awk '/^[[:space:]]*(```|~~~)/ { f = !f; next } !f' os/worklog.md \
    | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} [^:]+: ' | tail -n 5 | awk '{
      if (length($0) > 160) { s = substr($0, 1, 160); sub(/[^ ]*$/, "", s); sub(/[[:space:],.;:-]+$/, "", s); $0 = s " …" }
      print "  " $0 }')
  if [ -n "$rec" ]; then
    out "newest receipts (os/worklog.md):"
    printf '%s\n' "$rec"
  else
    # Just after a yearly rotation, point at the epoch that holds them (law 9).
    la=$(find archive -maxdepth 1 -type f -name 'worklog-*.md' 2>/dev/null | sort | tail -n 1)
    [ -z "$la" ] || out "no receipts since the yearly rotation — the last ones are in $la"
  fi
fi

now=$(date +%s)
od=$(oldest_dirty "$ROOT" MAP.md STATUS.md DESK.md)
if [ -n "$od" ]; then
  n=${od%% *}; e=${od#* }
  age=""
  [ "$e" -gt 0 ] && age=", oldest from $(epoch_date "$e")"
  out "$n uncommitted file(s) here$age — another session's work in flight, or left behind: sync only your own paths"
fi

if [ -f os/satellites.txt ]; then
  satellite_list |
  while IFS= read -r sp; do
    git -C "$sp" rev-parse --git-dir >/dev/null 2>&1 || continue
    sn=$(basename "$sp")
    sod=$(oldest_dirty "$sp")
    sa=0
    git -C "$sp" rev-parse -q --verify '@{u}' >/dev/null 2>&1 && sa=$(git -C "$sp" rev-list --count '@{u}..HEAD')
    if [ -n "$sod" ]; then
      se=${sod#* }
      sage=""
      [ "$se" -gt 0 ] && sage=" since $(epoch_date "$se")"
      if [ "$se" -gt 0 ] && [ $((now - se)) -gt 86400 ]; then
        out "satellite $sn: ${sod%% *} uncommitted file(s)$sage — sync skips it until the owner reviews them (SATELLITE-CONFIRMED)"
      else
        out "satellite $sn: ${sod%% *} uncommitted file(s)$sage"
      fi
    fi
    [ "$sa" -eq 0 ] || out "satellite $sn: $sa unpushed commit(s) — sync.sh pushes them"
  done
fi

cat <<'EOF'
This session syncs itself — nobody types /sync. When a unit of work is done:
  os/scripts/sync.sh "<what you did>" --receipt "<topic>: <one line>" -- <the paths you changed>
EOF
exit 0
