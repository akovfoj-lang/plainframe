#!/usr/bin/env bash
# tool-guard.sh — Claude Code PreToolUse hook: law 7 and the Never tier at the
# moment a tool runs, not only at commit. Sessions often run in bypass mode,
# where nothing else stands between a tool call and the tree.
#
# Edit, Write, MultiEdit, NotebookEdit on a protected path, or inside .git/ (PROTECTED_NAMES and
# PROTECTED_ANYWHERE in os/scripts/lib/guard.sh, their one home — law 3):
# "ask". Drafting a protected change in the tree is allowed; the owner sees
# the prompt, and the commit gate still enacts. The path is resolved first
# (symlinks, `..`) and compared without regard to letter case; a path outside
# this repo is none of this hook's business.
#
# Bash — the Never tier: "deny" a force-push, a `--no-verify` (or a
# `core.hooksPath` override) that skips the git hooks, and a command that
# prints a .env file. Read of a .env file: "deny". The `.env.example`,
# `.env.sample` and `.env.template` files hold no secrets and pass.
#
# Anything else: no output, so the normal permission flow applies. A Bash
# command that writes a protected file (sed -i, >) is not judged here; the git
# hooks still stop it at commit. This binds Claude Code only — the git hooks
# bind every agent.
#
# Wired in .claude/settings.json. Reads the hook's JSON on stdin.

set -u
IN=$(cat)
ROOT=${CLAUDE_PROJECT_DIR:-$PWD}
ROOT=$(cd "$ROOT" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0

# shellcheck source=../lib/json.sh
. "$ROOT/os/scripts/lib/json.sh"

decide() {  # DECISION REASON
  r=$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$r"
  exit 0
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

secret_env() {  # PATH-OR-WORD — true for .env and .env.*, never the examples
  case $(lower "${1##*/}") in
    .env.example|.env.sample|.env.template) return 1 ;;
    .env|.env.*) return 0 ;;
  esac
  return 1
}

# repo_path FILE — prints FILE relative to this repo, symlinks resolved, or
# fails when it lies outside it. FILE may not exist yet: its nearest existing
# folder is resolved and the rest appended. A symlink at the end resolves to
# where the write would land.
repo_path() {  # FILE [DEPTH]
  rp_depth=${2:-0}; [ "$rp_depth" -lt 8 ] || return 1
  rp_dir=$(dirname "$1"); rp_rest=$(basename "$1")
  while [ ! -d "$rp_dir" ]; do
    rp_rest="$(basename "$rp_dir")/$rp_rest"; rp_dir=$(dirname "$rp_dir")
  done
  if [ -L "$rp_dir/$rp_rest" ]; then
    rp_t=$(readlink "$rp_dir/$rp_rest")
    case $rp_t in /*) ;; *) rp_t="$rp_dir/$rp_t" ;; esac
    repo_path "$rp_t" $((rp_depth + 1)); return
  fi
  rp_top=$(cd "$rp_dir" && git rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(lower "$rp_top")" = "$(lower "$ROOT")" ] || return 1
  rp_pre=$(cd "$rp_dir" && git rev-parse --show-prefix)
  printf '%s%s' "$rp_pre" "$rp_rest"
}

protected() {  # REPO-RELATIVE PATH
  pr_p=$(lower "$1")
  # shellcheck source=../lib/guard.sh
  . "$ROOT/os/scripts/lib/guard.sh"
  for pr_n in $PROTECTED_NAMES; do
    pr_n=$(lower "$pr_n")
    case $pr_p in "$pr_n"|"$pr_n"/*) return 0 ;; esac
  done
  for pr_n in $PROTECTED_ANYWHERE; do
    pr_n=$(lower "$pr_n")
    case $pr_p in "$pr_n"|*/"$pr_n") return 0 ;; esac
  done
  return 1
}

TOOL=$(printf '%s' "$IN" | json_str tool_name) || exit 0
case $TOOL in
  Edit|Write|MultiEdit|NotebookEdit)
    f=$(printf '%s' "$IN" | json_str file_path) || f=$(printf '%s' "$IN" | json_str notebook_path) || exit 0
    case $f in /*) ;; *) f="$ROOT/$f" ;; esac
    fd=$(cd "$(dirname "$f")" 2>/dev/null && pwd -P) || fd=$(dirname "$f")
    case $(lower "$fd")/ in "$(lower "$ROOT")"/.git/*)
      decide ask "$(basename "$f") in .git/ is git's own state (core.hooksPath lives in .git/config): changing it by hand can switch off the git hooks, so it needs the owner's explicit yes in this session." ;;
    esac
    rel=$(repo_path "$f") || exit 0
    if protected "$rel"; then
      decide ask "$rel is a protected path (law 7): drafting it is fine, but it changes only with the owner's explicit yes in this session, and the commit needs OWNER-CONFIRMED as its own line."
    fi
    ;;
  Read)
    f=$(printf '%s' "$IN" | json_str file_path) || exit 0
    if secret_env "$f"; then
      decide deny "Never tier: reading a .env file would print its secret values into this session. Use the variable's name, and ask the owner to check the value."
    fi
    ;;
  Bash)
    cmd=$(printf '%s' "$IN" | json_str command) || exit 0
    # Judged line by line, as the shell runs it: a backslash-newline joins two
    # lines, and a heredoc's body is text, not a command — a commit message
    # that mentions .env or --no-verify is not one that runs them.
    one=$(printf '%s\n' "$cmd" | LC_ALL=C awk '
      hd != "" { t = $0; if (strip) sub(/^\t+/, "", t); if (t == hd) hd = ""; next }
      {
        line = pend $0; pend = ""
        if (line ~ /\\$/) { pend = substr(line, 1, length(line) - 1); next }
        if (match(line, /<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*["'"'"']?/) \
            && substr(line, RSTART - 1, 1) != "<") {
          w = substr(line, RSTART, RLENGTH); strip = (w ~ /^<<-/)
          sub(/^<<-?[ \t]*/, "", w); gsub(/["'"'"']/, "", w); hd = w
        }
        print line
      }
      END { if (pend != "") print pend }')
    if printf '%s' "$one" | grep -Eq 'git[^;&|]*[[:space:]]push[^;&|]*[[:space:]](-[A-Za-z]*f[A-Za-z]*|--force[^[:space:]]*|\+[^[:space:]]+)([[:space:]]|$)'; then
      decide deny "Never tier: a force-push rewrites history someone may already hold. Push normally; if it is refused, pull and resolve (os/playbooks/resolve-conflict.md)."
    fi
    if printf '%s' "$one" | grep -Eq 'git[^;&|]*[[:space:]](--no-verify|-c[[:space:]]*core\.hooks[Pp]ath=)|git[^;&|]*[[:space:]]commit[^;&|]*[[:space:]]-[A-Za-z]*n[A-Za-z]*([[:space:]]|$)'; then
      decide deny "Skipping the git hooks is the owner's break-glass call, never an agent's (CLAUDE.md, Protected paths). If a hook blocks, say what it said and ask the owner."
    fi
    clean=$(printf '%s' "$one" | sed -E 's/\.env\.(example|sample|template)//g')
    if printf '%s' "$clean" | grep -Eq '(^|[;&|(`[:space:]])(cat|less|more|head|tail|bat|nl|tac|strings|xxd|od|hexdump|grep|egrep|fgrep|rg|awk|sed|cut|sort|base64)([[:space:]][^;&|]*)?[[:space:]/<"'"'"'=]\.env(\.[A-Za-z0-9_-]+)?([[:space:];&|)"'"'"'`]|$)'; then
      decide deny "Never tier: this would print a .env file's secret values into this session. Use the variable's name, and ask the owner to check the value."
    fi
    ;;
esac
exit 0
