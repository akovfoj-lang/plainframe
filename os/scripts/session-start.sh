#!/usr/bin/env bash
# session-start.sh — the start of every session, done by the machine (law 8).
#
# Usage: os/scripts/session-start.sh
#
# Claude Code runs this by itself at startup (.claude/settings.json, the
# SessionStart hook) and hands the agent its report before the first word;
# any other agent runs it as its first command (AGENTS.md). It replaces the
# hand-typed `git pull` + generator checks, which an agent could not do
# before reading CLAUDE.md in a tool that loads CLAUDE.md for it (PF-039).
#
#   1. Brings GitHub's side down: fetch, then fast-forward; or, when both
#      sides moved and this tree is clean, rebase this machine's own unpushed
#      commits on top (the same rules as sync.sh, lib/converge.sh). A dirty
#      tree is never stashed, reset or rebased — it may be another session's
#      work in flight. Never commits, never pushes.
#   2. Says so when CLAUDE.md or AGENTS.md changed underneath you: re-read.
#   3. Runs the generators' --check modes and names anything stale.
#   4. Names uncommitted or unpushed work — here (with its age: another
#      session's, or something left behind) and in each satellite.
#   5. Reminds the session that it syncs itself.
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
if [ -z "$branch" ]; then
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
    if [ -z "$u" ] || [ "$u" = "$h" ]; then
      out "up to date with ${up%% *}"
    elif git merge-base --is-ancestor "$h" "$u"; then
      n=$(git rev-list --count "$h..$u")
      if git merge -q --ff-only "$u" >/dev/null 2>&1; then
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
        out "both sides had moved and these conflict: $(printf '%s ' $CONVERGE_CONFLICTS)— nothing changed; resolve per os/playbooks/resolve-conflict.md"
      fi
    else
      out "both sides have moved and this tree has uncommitted edits — not touched; sync.sh rebases once your work is committed"
    fi
  fi
fi

[ "$(hash_of CLAUDE.md)" = "$before_claude" ] || out "CLAUDE.md changed in that pull — re-read it in full before continuing (law 8)"
[ "$(hash_of AGENTS.md)" = "$before_agents" ] || out "AGENTS.md changed in that pull — re-read it too"

stale=""
for g in gen-map gen-status gen-desk gen-commands; do
  [ -f "os/scripts/$g.sh" ] || continue
  /bin/bash "os/scripts/$g.sh" --check >/dev/null 2>&1 || stale="$stale $g"
done
if [ -n "$stale" ]; then
  out "stale views:$stale — regenerate before trusting them (sync.sh does it for you)"
else
  out "views current (MAP, STATUS, DESK, adapters)"
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
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' os/satellites.txt | sed '/^$/d' |
  while IFS= read -r sp; do
    # shellcheck disable=SC2088  # matching a literal "~/" prefix, not expanding it
    case $sp in "~/"*) sp="$HOME/${sp#\~/}" ;; esac
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
