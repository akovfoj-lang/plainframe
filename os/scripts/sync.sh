#!/usr/bin/env bash
# sync.sh — persistence, both ways: satellites first, main last (law 8).
#
# Usage:
#   os/scripts/sync.sh "<message>" [--receipt "<line>"]... [-- <path>...]
#
# The session runs this itself, after each finished unit of work and before it
# ends; nobody has to type /sync for it to happen (CLAUDE.md, law 8).
#
# Scope (PF-030). With `-- <path>...`, only those paths are committed in this
# repo, plus the regenerated views; everything else in the working tree —
# another session's half-written page, a note the owner is still typing — is
# left exactly as it was, uncommitted and unchanged. Without paths, everything
# is committed, as before. The commit is built in a scratch worktree of its own
# (HEAD plus the paths in scope, views regenerated there), so it can never pick
# up anything else, and this tree is then moved onto the result without
# touching anyone else's files.
#
# --receipt "<line>" (repeatable) appends a receipt for the work itself to
# os/worklog.md inside that same commit, "YYYY-MM-DD " prefixed when the line
# has no date — so os/worklog.md never has to be passed as a path just to carry
# a receipt (another session may have lines of its own in it). `--receipt
# "<line>" --` with no paths after it syncs the receipt alone.
#
# Per repo (each satellite in os/satellites.txt, then this repo):
#   1. commit what is in scope;
#   2. fetch, then bring both sides together (PF-033): fast-forward when only
#      GitHub moved; when both moved, rebase this machine's own unpushed
#      commits on top — the one rewrite the constitution allows; never a
#      merge, never a force-push. Views that conflict are regenerated, and
#      os/worklog.md cannot conflict (merge=union in .gitattributes). Any other
#      conflict aborts cleanly and stops with PULL BLOCKED: nothing is lost,
#      your commit stays here unpushed; resolve per
#      os/playbooks/resolve-conflict.md, then rerun;
#   3. push.
# Then, once the outcome is known, it appends its own receipt
# ("YYYY-MM-DD sync: ...") to os/worklog.md and pushes that too — the two
# passes PF-015 requires, without anyone running them by hand (PF-034).
# Nothing to commit, pull or push means no receipt either.
#
# Protected-path gate (law 7; main repo; only what is in scope): a change to a
# path in PROTECTED_PATHS (os/scripts/lib/guard.sh) blocks the sync unless the
# message has OWNER-CONFIRMED as its own line (see guard.sh for the exact rule
# — a mention, prefix, or negation never counts); os/decisions.md is gated as
# os/guard.conf says. The commit-msg and pre-push hooks run the same gate
# again, so a raw git commit or push cannot slip past it (PF-003, PF-037).
#
# Satellite guard (PF-006): a satellite with its own uncommitted work is never
# swept into a commit sight-unseen. It still takes GitHub's side when that is a
# clean fast-forward, but nothing of it is staged, committed or pushed unless
# the message has SATELLITE-CONFIRMED as its own line — a separate token from
# OWNER-CONFIRMED on purpose — and the run then ends PARTIAL, never OK, so a
# skipped satellite cannot rot behind a line saying all is synced (PF-031).
#
# Exit: 0 everything synced · 1 blocked (protected path, conflict, refused
#       commit or push) · 2 usage or internal error · 3 partial — something was
#       skipped or left; the PARTIAL line says what.

set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi
LC_ALL=C
export LC_ALL

usage() {
  echo 'usage: os/scripts/sync.sh "<message>" [--receipt "<line>"]... [-- <path>...]' >&2
  exit 2
}

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

[ $# -ge 1 ] || usage
MSG=$1
shift
[ -n "$MSG" ] || usage
TODAY=$(date +%Y-%m-%d)
NL='
'
RECEIPTS=()
PATHS=()
SCOPED=0
while [ $# -gt 0 ]; do
  case $1 in
    --receipt)
      [ $# -ge 2 ] || usage
      case $2 in *"$NL"*|'') echo "sync.sh: a receipt is one non-empty line" >&2; exit 2 ;; esac
      if printf '%s\n' "$2" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '; then
        RECEIPTS+=("$2")
      else
        RECEIPTS+=("$TODAY $2")
      fi
      shift 2 ;;
    --) shift; SCOPED=1; PATHS=("$@"); break ;;
    *) usage ;;
  esac
done
if [ "$SCOPED" -eq 1 ]; then
  # `--` with no paths is a receipt-only sync: nothing of the tree is taken.
  [ ${#PATHS[@]} -gt 0 ] || [ ${#RECEIPTS[@]} -gt 0 ] || usage
  for p in ${PATHS[@]+"${PATHS[@]}"}; do
    if [ ! -e "$p" ] && [ -z "$(git ls-files -- "$p" 2>/dev/null)" ]; then
      echo "sync.sh: no such path, tracked or on disk: $p" >&2
      exit 2
    fi
  done
else
  PATHS=(.)
fi

BRANCH=$(git symbolic-ref -q --short HEAD) || {
  echo "BLOCKED: this tree is on a detached HEAD — check out a branch, then rerun" >&2
  exit 1
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sync.XXXXXX")
WT=""
cleanup() {
  if [ -n "$WT" ]; then
    git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"
    git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

# shellcheck source=lib/guard.sh
. "$ROOT/os/scripts/lib/guard.sh"
# shellcheck source=lib/converge.sh
. "$ROOT/os/scripts/lib/converge.sh"

short() { git -C "$ROOT" rev-parse --short "$1"; }

# -- Protected-path gate: only what this sync would actually commit ----------
: > "$TMP/scope"
if [ ${#PATHS[@]} -gt 0 ]; then
  git status --porcelain=v1 -uall -- "${PATHS[@]}" | sort > "$TMP/scope"
fi
# shellcheck disable=SC2086
git status --porcelain=v1 -uall -- $PROTECTED_PATHS | sort > "$TMP/protall"
comm -12 "$TMP/scope" "$TMP/protall" > "$TMP/prot"
if grep -q ' os/decisions\.md$' "$TMP/scope"; then
  if git cat-file -e HEAD:os/decisions.md 2>/dev/null; then
    git show HEAD:os/decisions.md > "$TMP/ledger-old"
  else
    : > "$TMP/ledger-old"
  fi
  if [ -f os/decisions.md ]; then cp os/decisions.md "$TMP/ledger-new"; else : > "$TMP/ledger-new"; fi
  if ledger_needs_token "$TMP/ledger-old" "$TMP/ledger-new"; then
    grep ' os/decisions\.md$' "$TMP/scope" >> "$TMP/prot"
  fi
fi
if [ -s "$TMP/prot" ] && ! owner_confirmed "$MSG"; then
  echo "BLOCKED: protected paths changed (law 7 — agents draft, the owner enacts):" >&2
  sed 's/^/  /' "$TMP/prot" >&2
  echo "OWNER-CONFIRMED is an owner-only token — only the owner can approve this in-session." >&2
  cat >&2 <<'EOF'
With the owner's explicit in-session yes, rerun with a commit message that has
OWNER-CONFIRMED as its own line (trimmed of surrounding whitespace) — a
mention, prefix, or negation elsewhere in the message never counts. Example:
  os/scripts/sync.sh "<commit message>
OWNER-CONFIRMED" -- <paths>
EOF
  exit 1
fi

PARTIAL=""
add_partial() { if [ -z "$PARTIAL" ]; then PARTIAL=$1; else PARTIAL="$PARTIAL; $1"; fi; }
SYNCED=""
add_synced() { if [ -z "$SYNCED" ]; then SYNCED=$1; else SYNCED="$SYNCED, $1"; fi; }
MOVED=0

# converge_and_push DIR BRANCH LABEL MODE — both ways for one repo. MODE is
# "inplace" (a satellite's own tree, clean by now) or "scratch" (the detached
# worktree this repo's commit is built in). Sets CP_PUSHED, CP_OFFLINE.
converge_and_push() {
  cp_dir=$1; cp_branch=$2; cp_label=$3; cp_mode=$4
  CP_PUSHED=0
  CP_OFFLINE=0
  cp_up=$(upstream_of "$cp_dir" "$cp_branch")
  if [ -z "$cp_up" ]; then
    echo "note: $cp_label has no upstream — committed locally; nothing pulled or pushed"
    return 0
  fi
  cp_remote=${cp_up%% *}
  cp_mref=${cp_up#* }
  cp_rtrack="refs/remotes/$cp_remote/${cp_mref#refs/heads/}"
  cp_try=0
  while :; do
    cp_try=$((cp_try + 1))
    if ! quiet_fetch "$cp_dir" "$cp_remote"; then
      echo "note: $cp_label — could not reach $cp_remote (offline?); anything committed stays here, unpushed"
      CP_OFFLINE=1
      return 0
    fi
    cp_h=$(git -C "$cp_dir" rev-parse HEAD)
    cp_u=$(git -C "$cp_dir" rev-parse -q --verify "$cp_rtrack" || true)
    if [ -n "$cp_u" ] && [ "$cp_h" != "$cp_u" ]; then
      if git -C "$cp_dir" merge-base --is-ancestor "$cp_h" "$cp_u"; then
        if [ "$cp_mode" = scratch ]; then
          git -C "$cp_dir" checkout -q --detach "$cp_u" || return 1
        else
          git -C "$cp_dir" merge -q --ff-only "$cp_u" >/dev/null || return 1
        fi
        echo "pulled: $cp_label ← $(git -C "$cp_dir" rev-list --count "$cp_h..$cp_u") commit(s) from $cp_remote"
        MOVED=1
      elif ! git -C "$cp_dir" merge-base --is-ancestor "$cp_u" "$cp_h"; then
        if ! rebase_onto "$cp_dir" "$cp_u"; then
          echo "PULL BLOCKED — $cp_label: these files changed on both sides and cannot be settled mechanically:" >&2
          printf '%s\n' "$CONVERGE_CONFLICTS" | sed 's/^/  /' >&2
          echo "Nothing was lost: your commits are still here, unpushed. Resolve per os/playbooks/resolve-conflict.md, then rerun." >&2
          return 1
        fi
        echo "rebased: $cp_label — this machine's unpushed commit(s) now sit on top of $cp_remote's"
        MOVED=1
      fi
    fi
    cp_h=$(git -C "$cp_dir" rev-parse HEAD)
    [ "$cp_h" != "$cp_u" ] || return 0
    if git -C "$cp_dir" push -q "$cp_remote" "HEAD:$cp_mref" 2>"$TMP/push.err"; then
      CP_PUSHED=1
      echo "pushed: $cp_label → $cp_remote ($(git -C "$cp_dir" rev-parse --short HEAD))"
      return 0
    fi
    if [ "$cp_try" -ge 3 ] || ! grep -qE 'fetch first|non-fast-forward|stale info' "$TMP/push.err"; then
      echo "BLOCKED: the push of $cp_label was refused:" >&2
      sed 's/^/  /' "$TMP/push.err" >&2
      return 1
    fi
    # GitHub moved again between our fetch and our push: go round once more.
  done
}

# -- Satellites first --------------------------------------------------------
: > "$TMP/sats"
if [ -f os/satellites.txt ]; then
  # Strip comments and trim with sed — never xargs (apostrophes kill it).
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' os/satellites.txt \
    | sed '/^$/d' > "$TMP/sats"
fi
while IFS= read -r sp; do
  # shellcheck disable=SC2088  # matching a literal "~/" prefix, not expanding it
  case $sp in "~/"*) sp="$HOME/${sp#\~/}" ;; esac
  sname=$(basename "$sp")
  echo "== $sname"
  if [ ! -e "$sp" ]; then echo "skip: $sp (missing)"; continue; fi
  if ! git -C "$sp" rev-parse --git-dir >/dev/null 2>&1; then echo "skip: $sp (not a git repo)"; continue; fi
  sbranch=$(git -C "$sp" symbolic-ref -q --short HEAD) || {
    echo "skip: $sname is on a detached HEAD" >&2
    add_partial "$sname skipped (detached HEAD)"
    continue
  }
  sdirty=$(git -C "$sp" status --porcelain)
  if [ -n "$sdirty" ] && ! satellite_confirmed "$MSG"; then
    echo "ABORTED: $sname has uncommitted work sync has not been told to include (PF-006):" >&2
    printf '%s\n' "$sdirty" | sed 's/^/  /' >&2
    cat >&2 <<'EOF'
Review the files above. With the owner's explicit in-session review, rerun
with a commit message that has SATELLITE-CONFIRMED as its own line.
EOF
    sup=$(upstream_of "$sp" "$sbranch")
    if [ -n "$sup" ] && quiet_fetch "$sp" "${sup%% *}"; then
      git -C "$sp" merge -q --ff-only '@{u}' >/dev/null 2>&1 || true
    fi
    add_partial "$sname skipped ($(printf '%s\n' "$sdirty" | wc -l | tr -d ' ') uncommitted file(s) — needs the owner's review)"
    continue
  fi
  scommitted=0
  if [ -n "$sdirty" ]; then
    git -C "$sp" add -A
    git -C "$sp" commit -q -m "$MSG"
    scommitted=1
    echo "committed: $sname ($(git -C "$sp" rev-parse --short HEAD))"
  fi
  converge_and_push "$sp" "$sbranch" "$sname" inplace || exit 1
  if [ "$CP_OFFLINE" -eq 1 ]; then add_partial "$sname not pushed (offline)"; fi
  if [ "$CP_PUSHED" -eq 1 ] || [ "$scommitted" -eq 1 ]; then
    add_synced "$sname@$(git -C "$sp" rev-parse --short HEAD)"
  fi
done < "$TMP/sats"

# -- This repo last ------------------------------------------------------------
O=$(git rev-parse HEAD)

# The commit's tree: HEAD plus exactly the paths in scope, built in a private
# index so the real one — and anything another session has staged — is never
# touched.
GIT_INDEX_FILE="$TMP/index" git read-tree "$O"
if [ ${#PATHS[@]} -gt 0 ] && ! GIT_INDEX_FILE="$TMP/index" git add -A -- "${PATHS[@]}" 2>"$TMP/add.err"; then
  echo "sync.sh: could not stage the paths given:" >&2
  sed 's/^/  /' "$TMP/add.err" >&2
  exit 2
fi
T=$(GIT_INDEX_FILE="$TMP/index" git write-tree)

WT="$TMP/wt"
if ! git worktree add -q --detach "$WT" "$O" >"$TMP/wt.err" 2>&1; then
  echo "sync.sh: could not create a scratch worktree (internal error):" >&2
  sed 's/^/  /' "$TMP/wt.err" >&2
  WT=""
  exit 2
fi
git -C "$WT" read-tree -m -u "$O" "$T"

# The views describe this tree's real git state (branch, unpushed, dirty) —
# not the scratch worktree's, which is detached and clean by construction.
PLAINFRAME_LIVE_ROOT=$ROOT
export PLAINFRAME_LIVE_ROOT

append_line() {
  if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then printf '\n' >> "$1"; fi
  printf '%s\n' "$2" >> "$1"
}

# commit_scratch MESSAGE — regenerate, stage everything in the scratch tree,
# commit if anything changed. Sets COMMITTED. Returns 2 if a generator failed,
# 1 if a hook refused the commit — the caller decides, because a refused
# receipt commit comes after the work is already pushed.
commit_scratch() {
  COMMITTED=0
  if ! regen_views "$WT"; then
    echo "sync.sh: a generator failed in the scratch worktree (internal error)" >&2
    return 2
  fi
  git -C "$WT" add -A
  git -C "$WT" diff --cached --quiet && return 0
  if ! git -C "$WT" commit -q -m "$1" 2>"$TMP/commit.err"; then
    echo "BLOCKED: the commit was refused by a hook:" >&2
    sed 's/^/  /' "$TMP/commit.err" >&2
    return 1
  fi
  [ -s "$TMP/commit.err" ] && sed 's/^/  /' "$TMP/commit.err" >&2
  COMMITTED=1
}

# advance_main TO — move this tree's branch to TO without touching anyone
# else's files. Files the move would change and that are dirty here are only
# ever: already identical to TO (staged so the move keeps them), a view
# (regenerated, so reset), or os/worklog.md with lines appended here (set
# aside and re-appended after). Anything else — someone's uncommitted edit to
# a file the pulled commits also change — leaves the tree where it is.
advance_main() {
  am_to=$1
  am_from=$(git rev-parse HEAD)
  [ "$am_from" != "$am_to" ] || return 0
  if [ "$am_from" != "$O" ] && ! git merge-base --is-ancestor "$am_from" "$am_to"; then
    add_partial "pushed, but this tree moved on while syncing ($(short "$am_from")) and stays put — run 'git pull --ff-only' once that work is pushed"
    return 0
  fi
  git diff --name-only "$am_from" "$am_to" > "$TMP/changing"
  : > "$TMP/dirty"
  am_skip=0
  while IFS= read -r -d '' am_rec; do
    if [ "$am_skip" -eq 1 ]; then am_skip=0; continue; fi
    case ${am_rec%"${am_rec#??}"} in R*|C*) am_skip=1 ;; esac
    printf '%s\n' "${am_rec#???}" >> "$TMP/dirty"
  done < <(git status --porcelain=v1 -uall -z)
  : > "$TMP/stage"; : > "$TMP/reset"; : > "$TMP/stuck"
  am_wl=0
  while IFS= read -r f; do
    grep -qxF -- "$f" "$TMP/dirty" || continue
    if [ -e "$f" ]; then am_have=$(git hash-object -- "$f"); else am_have=none; fi
    am_want=$(git rev-parse -q --verify "$am_to:$f" 2>/dev/null || echo none)
    if [ "$am_have" = "$am_want" ]; then
      printf '%s\n' "$f" >> "$TMP/stage"
    elif is_view "$f"; then
      printf '%s\n' "$f" >> "$TMP/reset"
    elif [ "$f" = os/worklog.md ] && [ -f "$f" ]; then
      git show "$am_from:os/worklog.md" > "$TMP/wl-from" 2>/dev/null || : > "$TMP/wl-from"
      am_n=$(wc -c < "$TMP/wl-from"); am_n=$((am_n))
      if head -c "$am_n" "$f" | cmp -s - "$TMP/wl-from"; then
        tail -c "+$((am_n + 1))" "$f" > "$TMP/wl-extra"
        am_wl=1
      else
        printf '%s\n' "$f" >> "$TMP/stuck"
      fi
    else
      printf '%s\n' "$f" >> "$TMP/stuck"
    fi
  done < "$TMP/changing"
  if [ -s "$TMP/stuck" ]; then
    add_partial "pushed $(short "$am_to"), but this tree stays at $(short "$am_from"): $(tr '\n' ' ' < "$TMP/stuck")has uncommitted edits here that the update also changes — commit or set them aside, then run 'git merge --ff-only $(short "$am_to")'"
    return 0
  fi
  while IFS= read -r f; do
    if [ -e "$f" ]; then git add -- "$f"; else git rm -q --cached --ignore-unmatch -- "$f"; fi
  done < "$TMP/stage"
  while IFS= read -r f; do
    if git cat-file -e "$am_from:$f" 2>/dev/null; then
      git checkout -q "$am_from" -- "$f"
    else
      git rm -q --cached --ignore-unmatch -- "$f"
      rm -f -- "$f"
    fi
  done < "$TMP/reset"
  [ "$am_wl" -eq 0 ] || git checkout -q "$am_from" -- os/worklog.md
  if ! git update-ref -m "sync: move to $(short "$am_to")" "refs/heads/$BRANCH" "$am_to" "$am_from" \
     || ! git read-tree -m -u "$am_from" "$am_to"; then
    git update-ref "refs/heads/$BRANCH" "$am_from" "$am_to" 2>/dev/null || true
    [ "$am_wl" -eq 0 ] || cat "$TMP/wl-extra" >> os/worklog.md
    add_partial "pushed $(short "$am_to"), but this tree could not be moved onto it — run 'git merge --ff-only $(short "$am_to")'"
    return 0
  fi
  if [ "$am_wl" -eq 1 ]; then
    # Lines only this tree had (another session's receipts, not yet synced)
    # go back on the end, minus any that the update already carries.
    awk 'NR == FNR { have[$0] = 1; next } !($0 in have)' os/worklog.md "$TMP/wl-extra" > "$TMP/wl-back"
    cat "$TMP/wl-back" >> os/worklog.md
  fi
}

finish_blocked() {
  advance_main "$(git -C "$WT" rev-parse HEAD)"
  exit 1
}

# Pass 1: the work. Views alone are not work: their live lines (branch, dirty
# count, satellites) differ on every regen, so with nothing else in scope and
# no receipt to carry there is nothing to commit — not a STATUS-only commit.
C1=0
if [ ${#RECEIPTS[@]} -gt 0 ] || ! git diff --quiet "$O" "$T" -- . \
     ':(exclude)MAP.md' ':(exclude)STATUS.md' ':(exclude)DESK.md' \
     ':(exclude).claude/commands' ':(exclude).agents/skills'; then
  for r in ${RECEIPTS[@]+"${RECEIPTS[@]}"}; do append_line "$WT/os/worklog.md" "$r"; done
  commit_scratch "$MSG" || exit $?
  C1=$COMMITTED
fi
[ "$C1" -eq 0 ] || echo "committed: main ($(git -C "$WT" rev-parse --short HEAD))"
converge_and_push "$WT" "$BRANCH" main scratch || finish_blocked
P1=$CP_PUSHED
OFF=$CP_OFFLINE

# Pass 2: the receipt, written only now that the outcome is known.
if [ "$OFF" -eq 0 ] && { [ "$C1" -eq 1 ] || [ "$P1" -eq 1 ] || [ -n "$SYNCED" ]; }; then
  SUMMARY=$(printf '%s\n' "$MSG" | head -n 1 | awk '{
    if (length($0) <= 80) { print; exit }
    s = substr($0, 1, 80); sub(/[^ ]*$/, "", s); sub(/[[:space:],.;:-]+$/, "", s); print s " …" }')
  line="$TODAY sync: $SUMMARY — main@$(git -C "$WT" rev-parse --short HEAD)"
  [ -z "$SYNCED" ] || line="$line, $SYNCED"
  [ -z "$PARTIAL" ] || line="$line; partial: $PARTIAL"
  append_line "$WT/os/worklog.md" "$line"
  if commit_scratch "worklog: sync receipt for $(git -C "$WT" rev-parse --short HEAD)"; then
    converge_and_push "$WT" "$BRANCH" main scratch || finish_blocked
    [ "$CP_OFFLINE" -eq 0 ] || OFF=1
  else
    # The work is already pushed; only its receipt is missing. Say so, and
    # still move this tree onto what was pushed.
    git -C "$WT" reset -q --hard HEAD
    add_partial "the work is pushed, but its sync receipt was refused (above) — add it by hand"
  fi
fi
[ "$OFF" -eq 0 ] || add_partial "main not pushed (offline) — the next sync pushes it"

advance_main "$(git -C "$WT" rev-parse HEAD)"

if [ "$SCOPED" -eq 1 ]; then
  left=$(git status --porcelain | wc -l | tr -d ' ')
  [ "$left" -eq 0 ] || echo "left as they were: $left uncommitted file(s) outside the paths given — not this sync's to commit"
fi

if [ -n "$PARTIAL" ]; then
  echo "PARTIAL: $PARTIAL"
  exit 3
fi
if [ "$C1" -eq 0 ] && [ "$P1" -eq 0 ] && [ -z "$SYNCED" ] && [ "$MOVED" -eq 0 ]; then
  echo "OK: nothing to sync"
  exit 0
fi
echo "OK: synced — main@$(git rev-parse --short HEAD)${SYNCED:+, $SYNCED}"
