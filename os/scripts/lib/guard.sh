# shellcheck shell=bash disable=SC2034  # sourced: PROTECTED_PATHS is read by the callers
# guard.sh — protected-path + owner-token logic shared by sync.sh,
# os/scripts/hooks/commit-msg and os/scripts/hooks/pre-push (law 3: one home
# per fact — the enforcement points must never drift apart, so they source the
# same list and the same matching rules instead of each keeping its own copy).
#
# Sourced, not executed, from the repo root (callers cd there first). Provides:
#
#   PROTECTED_PATHS   space-separated pathspecs (word-split on purpose; none
#                     of these contain spaces). os/decisions.md is not in this
#                     list: how the ledger is gated is the owner's setting,
#                     LEDGER_GATE below.
#
#   LEDGER_GATE       `ledger_gate=` in os/guard.conf (itself protected):
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
#                       the token passed as an approval (PF-036).
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
#                       byte length has no such edge case), and nothing added
#                       after that prefix declares itself "**Status:**
#                       confirmed" (an agent cannot self-confirm — law 2/7).
#                       A diff's +/- summary alone cannot tell a true
#                       end-of-file append from a mid-entry insertion that
#                       git's LCS matcher happens to render as pure additions
#                       when the inserted line matches nothing later in the
#                       file (PF-005) — the byte-exact prefix check closes
#                       that gap regardless.
#
#   ledger_needs_token OLD NEW   true when the gate is on and NEW is not a
#                       pure append onto OLD.

PROTECTED_PATHS='CLAUDE.md AGENTS.md os/scripts os/playbooks os/commands.md os/guard.conf .gitignore .gitattributes os/satellites.txt .claude/settings.json .github/workflows'

LEDGER_GATE=append-only
if [ -f os/guard.conf ]; then
  lg_val=$(sed -n 's/^[[:space:]]*ledger_gate[[:space:]]*=[[:space:]]*\([a-z-]*\)[[:space:]]*$/\1/p' os/guard.conf | tail -n 1)
  case $lg_val in off|append-only) LEDGER_GATE=$lg_val ;; esac
fi

has_token() {
  ht_msg=$1
  ht_tok=$2
  printf '%s\n' "$ht_msg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -qxF "$ht_tok"
}

clean_msg() {
  cm_cc=$(git config core.commentChar 2>/dev/null || true)
  case $cm_cc in ''|auto) cm_cc='#' ;; esac
  awk -v cc="$cm_cc" '
    $0 == cc " ------------------------ >8 ------------------------" { exit }
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
  if tail -c "+$((lao_old_size + 1))" "$lao_new" 2>/dev/null \
      | grep -E '\*\*Status:\*\*[[:space:]]*confirmed' >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

ledger_needs_token() {
  [ "$LEDGER_GATE" != off ] || return 1
  ! ledger_append_only "$1" "$2"
}
