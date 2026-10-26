# shellcheck shell=bash disable=SC2034  # sourced: PROTECTED_PATHS is read by the callers
# guard.sh — protected-path + owner-token logic shared by sync.sh,
# os/scripts/hooks/commit-msg and os/scripts/hooks/pre-push (law 3: one home
# per fact — the enforcement points must never drift apart, so they source the
# same list and the same matching rules instead of each keeping its own copy).
#
# Sourced, not executed, from the repo root (callers cd there first). Provides:
#
#   PROTECTED_NAMES   the protected paths in plain words, space-separated,
#                     for anything that compares paths itself; it must fold
#                     letter case and resolve symlinks first, as the hooks'
#                     pathspecs do the first.
#   PROTECTED_ANYWHERE  the names that count at any depth: agents load a
#                     nested CLAUDE.md, CLAUDE.local.md or AGENTS.md as instructions, and a
#                     nested .gitignore can un-ignore .env.
#   PROTECTED_PATHS   the same list as git pathspecs, word-split on purpose
#                     (none contains a space, and none starts with a name the
#                     shell's globbing could match). Letter case never
#                     matters: on a case-insensitive disk a `.GitHub/` entry
#                     lands in `.github/`. os/decisions.md is not in this
#                     list: how the ledger is gated is the owner's setting,
#                     LEDGER_GATE below.
#
#   EMPTY_TREE        the empty tree's id in this repo's hash, the base a
#                     root commit is judged against.
#
#   LEDGER_GATE       `ledger_gate=` in the COMMITTED os/guard.conf (itself
#                     protected; an uncommitted edit never judges a commit):
#                       append-only  template default — a pure append of draft
#                                    entries passes; anything else needs the
#                                    token (PF-005)
#                       off          the ledger commits freely; law 2 still
#                                    governs it, on the record instead of by a
#                                    hook (PF-040)
#                     A missing file or an unknown value reads as append-only:
#                     a typo must fail closed, never open.
#
#   has_token MSG TOK   true only if some line of MSG, after trimming leading
#                       and trailing whitespace, is EXACTLY TOK — a standalone
#                       approval line, never a prefix, an inline mention, a
#                       negation, or a quote. `git commit -m "this change is
#                       NOT OWNER-CONFIRMED yet, please review"` must never
#                       match (adversarial review finding, hardened past the
#                       original word-boundary-substring approach, which that
#                       message still passed). The convention is a commit
#                       message whose own line — typically the last — is
#                       nothing but the token, e.g.:
#                         "<summary>
#                       OWNER-CONFIRMED"
#
#   clean_msg FILE      prints a commit-message file the way it can count as
#                       approval: it stops at the scissors line that
#                       `git commit -v` puts above its diff and drops comment
#                       lines. commit-msg sees the raw file before git cleans
#                       it, so without this a diff line that was nothing but
#                       the token passed as an approval (PF-036). The scissors
#                       line is found whatever its comment prefix: with
#                       core.commentChar=auto git picks one this hook cannot
#                       know.
#
#   owner_confirmed MSG      has_token MSG OWNER-CONFIRMED
#   satellite_confirmed MSG  has_token MSG SATELLITE-CONFIRMED
#
#   ledger_append_only OLD NEW   true if file NEW is a pure append onto file
#                       OLD: every BYTE of OLD appears unmodified, in order,
#                       as an exact prefix of NEW (not "every line" — a line
#                       count via `wc -l` undercounts a file whose last line
#                       has no trailing newline, which used to false-block a
#                       legit append onto such a file; comparing by exact
#                       byte length has no such edge case), and what was added
#                       is draft and nothing else: every new `## ` entry has a
#                       `**Status:** draft` line, the spelling gen-desk.sh
#                       lists as waiting, and no added line is any other
#                       Status line, in any spelling (an agent cannot
#                       self-confirm — law 2/7). An append that continues a
#                       last line with no newline is judged with that line,
#                       so a Status line split over two appends is seen whole.
#                       A diff's +/- summary alone cannot tell a true
#                       end-of-file append from a mid-entry insertion that
#                       git's LCS matcher happens to render as pure additions
#                       when the inserted line matches nothing later in the
#                       file (PF-005) — the byte-exact prefix check closes
#                       that gap regardless.
#
#   ledger_needs_token OLD NEW   true when the gate is on and NEW is not a
#                       pure append onto OLD.

PROTECTED_NAMES='CLAUDE.md AGENTS.md CLAUDE.local.md os/scripts os/playbooks os/commands.md os/guard.conf .gitignore .gitattributes os/satellites.txt .claude/settings.json .claude/settings.local.json .claude/skills .claude/agents .claude/hooks .mcp.json .github/workflows'
PROTECTED_ANYWHERE='CLAUDE.md AGENTS.md CLAUDE.local.md .gitignore .gitattributes'
PROTECTED_PATHS=
for gp_name in $PROTECTED_NAMES; do PROTECTED_PATHS="$PROTECTED_PATHS :(icase)$gp_name"; done
for gp_name in $PROTECTED_ANYWHERE; do PROTECTED_PATHS="$PROTECTED_PATHS :(glob,icase)**/$gp_name"; done

EMPTY_TREE=$(git hash-object -t tree /dev/null)

# read_ledger_gate FILE — sets LEDGER_GATE from a guard.conf. Callers pass the
# committed one: an uncommitted edit to a protected setting must not be what
# judges the commit.
read_ledger_gate() {
  LEDGER_GATE=append-only
  if [ -f "$1" ]; then
    lg_val=$(sed -n 's/^[[:space:]]*ledger_gate[[:space:]]*=[[:space:]]*\([a-z-]*\)[[:space:]]*$/\1/p' "$1" | tail -n 1)
    case $lg_val in off|append-only) LEDGER_GATE=$lg_val ;; esac
  fi
}
gp_conf=$(mktemp "${TMPDIR:-/tmp}/guard-conf.XXXXXX")
git cat-file -p HEAD:os/guard.conf > "$gp_conf" 2>/dev/null || : > "$gp_conf"
read_ledger_gate "$gp_conf"
rm -f "$gp_conf"

has_token() {
  ht_msg=$1
  ht_tok=$2
  # Bytes, not characters: in a UTF-8 locale BSD sed stops at the first
  # invalid byte and hides every line after it.
  printf '%s\n' "$ht_msg" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | LC_ALL=C grep -qxF "$ht_tok"
}

clean_msg() {
  # core.commentString is git 2.45's longer name for core.commentChar; the
  # last one set wins.
  cm_cc=$(git config --get-regexp '^core\.comment(char|string)$' 2>/dev/null | tail -n 1 | sed 's/^[^ ]* //')
  case $cm_cc in ''|auto) cm_cc='#' ;; esac
  LC_ALL=C awk -v cc="$cm_cc" '
    /^[^ \t]+ ------------------------ >8 ------------------------\r?$/ { exit }
    index($0, cc) == 1 { next }
    { print }' "$1"
}

owner_confirmed() {
  has_token "$1" 'OWNER-CONFIRMED'
}

satellite_confirmed() {
  has_token "$1" 'SATELLITE-CONFIRMED'
}

ledger_append_only() {
  lao_old=$1
  lao_new=$2
  lao_old_size=$(wc -c < "$lao_old"); lao_old_size=$((lao_old_size))
  if [ "$lao_old_size" -gt 0 ]; then
    lao_tmp=$(mktemp "${TMPDIR:-/tmp}/ledger-check.XXXXXX")
    head -c "$lao_old_size" "$lao_new" > "$lao_tmp" 2>/dev/null || : > "$lao_tmp"
    if ! cmp -s "$lao_old" "$lao_tmp"; then
      rm -f "$lao_tmp"
      return 1
    fi
    rm -f "$lao_tmp"
  fi
  # What was added, with OLD's unfinished last line when the append continues it.
  if [ "$lao_old_size" -gt 0 ] && [ -n "$(tail -c 1 "$lao_old")" ] \
      && [ -n "$(tail -c "+$((lao_old_size + 1))" "$lao_new" | head -c 1)" ]; then
    { tail -n 1 "$lao_old"; tail -c "+$((lao_old_size + 1))" "$lao_new"; }
  else
    tail -c "+$((lao_old_size + 1))" "$lao_new"
  fi | LC_ALL=C awk '
    /^## / { if (open && !draft) bad = 1; open = 1; draft = 0; next }
    tolower($0) ~ /^[[:space:]>*_]*status[[:space:]*_]*:/ {
      if ($0 ~ /^\*\*Status:\*\*[[:space:]]*draft([^A-Za-z]|$)/) draft = 1; else bad = 1
    }
    END { if (open && !draft) bad = 1; exit bad }'
}

ledger_needs_token() {
  [ "$LEDGER_GATE" != off ] || return 1
  ! ledger_append_only "$1" "$2"
}
