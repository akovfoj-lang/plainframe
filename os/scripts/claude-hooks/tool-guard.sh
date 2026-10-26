#!/usr/bin/env bash
# tool-guard.sh — Claude Code PreToolUse hook: law 7 at the moment a tool
# runs, not only at commit. Sessions often run in bypass mode, where nothing
# else asks before a tool call reaches the tree.
#
# Edit, Write, MultiEdit, NotebookEdit on a protected path, or inside .git/
# (PROTECTED_NAMES and PROTECTED_ANYWHERE in os/scripts/lib/guard.sh, their
# one home — law 3): "ask". Drafting a protected change in the tree is
# allowed; the owner sees the prompt, and the commit gate still enacts. The
# path is resolved first (folder and file symlinks, `..` through folders that
# exist) and compared with Unicode case folding, so `AGENTſ.md` is AGENTS.md as
# a case-insensitive disk sees it; a path outside this repo is none of this
# hook's business.
#
# Only this hook asks in bypass mode: Claude Code's own "ask" rules don't
# prompt there (tested 2026-10-25), so it stays. The Never tier — force-push,
# skipping the git hooks, reading a .env file — is "deny" rules in
# .claude/settings.json, which do hold in bypass mode and judge each part of a
# chained command; this hook no longer looks at Bash or Read.
#
# A Bash command that writes a protected file (sed -i, >) is not judged here;
# the git hooks still stop it at commit. This binds Claude Code only — the git
# hooks bind every agent. When the hook itself can't run (no git, a missing
# library), it exits non-zero, and the `"onFailure": "block"` it is wired with
# blocks the call instead of letting it through.
#
# Wired in .claude/settings.json. Reads the hook's JSON on stdin.

set -u
IN=$(cat)
ROOT=${CLAUDE_PROJECT_DIR:-$PWD}
ROOT=$(cd "$ROOT" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 1
ROOT=$(cd "$ROOT" && pwd -P) || exit 1
cd "$ROOT" || exit 1

# shellcheck source=../lib/json.sh
. "$ROOT/os/scripts/lib/json.sh" || exit 1
# shellcheck source=../lib/guard.sh
. "$ROOT/os/scripts/lib/guard.sh" || exit 1
[ -n "${PROTECTED_NAMES:-}" ] || exit 1

decide() {  # DECISION REASON
  r=$(printf '%s' "$2" | tr -d '\000-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$r"
  exit 0
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# fold TEXT — Unicode case folding after NFKC, the way a case-insensitive disk
# matches names (ſ is s, the Kelvin sign is k). ASCII lower case without perl.
fold() {
  perl -CSA -MUnicode::Normalize -Mfeature=fc -e 'print fc(NFKC($ARGV[0]))' "$1" 2>/dev/null \
    || lower "$1"
}

# resolve FILE [DEPTH] — prints where a write to FILE lands, as a physical
# absolute path. FILE may not exist yet: its nearest existing folder is
# resolved and the rest appended. A symlink at the end is followed. Returns 2
# when a chain of symlinks is too long to follow.
resolve() {
  rs_depth=${2:-0}; [ "$rs_depth" -lt 32 ] || return 2
  rs_dir=$(dirname "$1"); rs_rest=$(basename "$1")
  while [ ! -d "$rs_dir" ]; do
    rs_rest="$(basename "$rs_dir")/$rs_rest"; rs_dir=$(dirname "$rs_dir")
  done
  rs_dir=$(cd "$rs_dir" && pwd -P) || return 1
  if [ -L "$rs_dir/$rs_rest" ]; then
    rs_t=$(readlink "$rs_dir/$rs_rest")
    case $rs_t in /*) ;; *) rs_t="$rs_dir/$rs_t" ;; esac
    resolve "$rs_t" $((rs_depth + 1)); return
  fi
  printf '%s/%s' "${rs_dir%/}" "$rs_rest"
}

protected() {  # FOLDED REPO-RELATIVE PATH
  for pr_n in $PROTECTED_NAMES; do
    pr_n=$(lower "$pr_n")
    case $1 in "$pr_n"|"$pr_n"/*) return 0 ;; esac
  done
  for pr_n in $PROTECTED_ANYWHERE; do
    pr_n=$(lower "$pr_n")
    case $1 in "$pr_n"|*/"$pr_n") return 0 ;; esac
  done
  return 1
}

TOOL=$(printf '%s' "$IN" | json_str tool_name) || exit 0
case $TOOL in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
f=$(printf '%s' "$IN" | json_str file_path) || f=$(printf '%s' "$IN" | json_str notebook_path) || exit 0
case $f in /*) ;; *) f="$ROOT/$f" ;; esac

abs=$(resolve "$f"); rc=$?
[ "$rc" -ne 2 ] || decide ask "$(basename "$f") sits at the end of a chain of symlinks too long to follow, so where the write lands can't be checked: it needs the owner's explicit yes in this session."
[ "$rc" -eq 0 ] || exit 0
fa=$(fold "$abs"); fr=$(fold "$ROOT")

case $fa in "$fr"/.git|"$fr"/.git/*)
  decide ask "$(basename "$abs") in .git/ is git's own state (core.hooksPath lives in .git/config): changing it by hand can switch off the git hooks, so it needs the owner's explicit yes in this session." ;;
esac
case $fa in "$fr"/*) ;; *) exit 0 ;; esac
rel=${fa#"$fr"/}
if protected "$rel"; then
  decide ask "$rel is a protected path (law 7): drafting it is fine, but it changes only with the owner's explicit yes in this session, and the commit needs OWNER-CONFIRMED as its own line."
fi
exit 0
