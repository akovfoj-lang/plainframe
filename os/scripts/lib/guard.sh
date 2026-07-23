# guard.sh — protected-path + owner-token logic shared by sync.sh and
# os/scripts/hooks/commit-msg (law 3: one home per fact — the two enforcement
# points must never drift apart, so they source the same list and the same
# matching rules instead of each keeping its own copy).
#
# Sourced, not executed. Requires TMP (a writable scratch dir) to already be
# set by the caller. Provides:
#
#   PROTECTED_PATHS   space-separated pathspecs (word-split on purpose; none
#                     of these contain spaces). os/decisions.md is deliberately
#                     NOT in this list — it gets its own append-only carve-out
#                     below instead of a blanket block.
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

PROTECTED_PATHS='CLAUDE.md AGENTS.md os/scripts os/playbooks os/commands.md .gitignore os/satellites.txt'

has_token() {
  ht_msg=$1
  ht_tok=$2
  printf '%s\n' "$ht_msg" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -qxF "$ht_tok"
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
