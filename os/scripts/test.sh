#!/usr/bin/env bash
# test.sh — end-to-end tests for the guardrails, sync and generators, run in
# throwaway repos (PF-042).
#
# Usage: os/scripts/test.sh      run everything; exit 1 if any check fails
#
# Builds a scratch world under $TMPDIR and touches nothing outside it: a copy
# of THIS working tree (tracked and untracked files; ignored ones left out) as
# a fresh repo, a bare repo standing in for GitHub, two clones standing in for
# two machines (or two sessions), and a fake satellite with a fake remote of
# its own. The real satellites in os/satellites.txt are swapped for the fake
# one before anything runs, and git's global config is replaced by a scratch
# one, so nothing here can reach a real remote. Prints PASS or FAIL per check,
# then a count. Run it before any kernel change; CI runs it on macOS and Linux
# (.github/workflows/check.yml).

set -u
LC_ALL=C
export LC_ALL

SRC=$(cd "$(dirname "$0")/../.." && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/plainframe-test.XXXXXX")
trap 'rm -rf "$W"' EXIT

cat > "$W/gitconfig" <<'EOF'
[init]
	defaultBranch = main
[commit]
	gpgsign = false
[advice]
	detachedHead = false
EOF
export GIT_CONFIG_GLOBAL="$W/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export PLAINFRAME_GITLEAKS=off
unset PLAINFRAME_LIVE_ROOT GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE

PASSED=0
FAILED=0
ok() { PASSED=$((PASSED + 1)); printf 'PASS  %s\n' "$1"; }
bad() {
  FAILED=$((FAILED + 1)); printf 'FAIL  %s\n' "$1"
  [ -z "${2:-}" ] || sed 's/^/        /' "$2" | head -n 25
}
# v NAME [OUTFILE] — PASS when the command list just before it succeeded:
#   cond1 && cond2; v "what must hold" "$W/out"
v() { if [ $? -eq 0 ]; then ok "$1"; else bad "$1" "${2:-}"; fi; }

regen() { (cd "$1" && for g in gen-commands gen-desk gen-map gen-status; do
  [ -f "os/scripts/$g.sh" ] && /bin/bash "os/scripts/$g.sh" >/dev/null 2>&1; done; true); }
put_line() { printf '%s\n' "$2" >> "$1"; }
# Replace line N of FILE with TEXT, portably (no sed -i: BSD and GNU differ).
set_line() { awk -v n="$2" -v s="$3" 'NR == n { print s; next } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
# Bounded input, no early close: GitHub's runner starts steps with SIGPIPE
# ignored, and BSD tr then reads /dev/urandom forever once head has hung up.
rand() { head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c "1-$1"; }
on_origin() { git -C "$W/origin.git" cat-file -e "main:$1" 2>/dev/null; }
origin_file() { git -C "$W/origin.git" show "main:$1" 2>/dev/null; }
sync_in() { d=$1; shift; (cd "$W/$d" && /bin/bash os/scripts/sync.sh "$@") > "$W/out" 2>&1; echo $? > "$W/rc"; }
rc() { cat "$W/rc"; }
said() { grep -qF -- "$1" "$W/out"; }

# -- The world -----------------------------------------------------------------
echo "building the scratch world in $W"
mkdir -p "$W/seed"
(cd "$SRC" && git ls-files -z -co --exclude-standard) > "$W/list0"
while IFS= read -r -d '' f; do [ -e "$SRC/$f" ] && printf '%s\0' "$f"; done < "$W/list0" > "$W/list1"
(cd "$SRC" && tar -cf - --null -T "$W/list1") | (cd "$W/seed" && tar -xf -)

git init -q --bare "$W/sat.git"
mkdir -p "$W/sat/docs/handoffs"
printf '# Handoff — sat one\n' > "$W/sat/docs/handoffs/2026-01-01-one.md"
(cd "$W/sat" && git init -q && git add -A && git commit -qm init \
  && git remote add origin "$W/sat.git" && git push -qu origin main) || { echo "could not build the satellite"; exit 2; }
SATBASE=$(git -C "$W/sat" rev-parse HEAD)

printf '%s\n' "$W/sat" > "$W/seed/os/satellites.txt"
printf 'ledger_gate=append-only\n' > "$W/seed/os/guard.conf"
regen "$W/seed"
(cd "$W/seed" && git init -q && git add -A && git commit -q --no-verify -m fixture) || { echo "could not build the fixture"; exit 2; }
git clone -q --bare "$W/seed" "$W/origin.git"
for m in A B; do
  git clone -q "$W/origin.git" "$W/$m"
  git -C "$W/$m" config core.hooksPath os/scripts/hooks
done
BASE=$(git -C "$W/A" rev-parse HEAD)

reset_world() {
  for m in A B; do
    git -C "$W/$m" rebase --abort >/dev/null 2>&1
    git -C "$W/$m" remote set-url origin "$W/origin.git"
    git -C "$W/$m" reset -q --hard "$BASE"
    git -C "$W/$m" clean -qfd
  done
  git -C "$W/A" push -qf --no-verify origin "$BASE:refs/heads/main" 2>/dev/null
  for m in A B; do git -C "$W/$m" fetch -q origin; done
  git -C "$W/sat" reset -q --hard "$SATBASE"
  git -C "$W/sat" clean -qfd
  git -C "$W/sat" push -qf origin "$SATBASE:refs/heads/main" 2>/dev/null
}
A="$W/A"
B="$W/B"

# -- Protected paths -------------------------------------------------------------
echo "== protected paths"
reset_world; put_line "$A/CLAUDE.md" x
! git -C "$A" commit -qam edit; v "protected path, no token: commit refused"
reset_world; put_line "$A/CLAUDE.md" x
! git -C "$A" commit -qam "OWNER-CONFIRMED: edit"; v "token as a prefix: refused"
reset_world; put_line "$A/CLAUDE.md" x
! git -C "$A" commit -qam "edit
this is NOT OWNER-CONFIRMED yet"; v "token negated: refused"
reset_world; put_line "$A/CLAUDE.md" x
git -C "$A" commit -qam "edit
   OWNER-CONFIRMED  "; v "standalone token, padded: accepted"
reset_world; printf 'a\nOWNER-CONFIRMED\nb\n' >> "$A/CLAUDE.md"
git -C "$A" commit -qam "seed a token-only line
OWNER-CONFIRMED"
n=$(wc -l < "$A/CLAUDE.md"); set_line "$A/CLAUDE.md" "$n" "b2"
! env GIT_EDITOR=true git -C "$A" commit -q -v -e -am "tweak"; v "token only in the -v diff: refused"
reset_world; put_line "$A/CLAUDE.md" x
git -C "$A" commit -qam "edit
OWNER-CONFIRMED"
git -C "$A" commit -q --amend -m "edit, approval amended away" 2>/dev/null
! git -C "$A" push -q origin HEAD:main; v "approval amended away: push refused"
reset_world; put_line "$A/CLAUDE.md" x
git -C "$A" commit -q --no-verify -am "edit with --no-verify"
! git -C "$A" push -q origin HEAD:main; v "--no-verify commit: push refused"
reset_world; put_line "$A/CLAUDE.md" x
git -C "$A" commit -qam "edit
OWNER-CONFIRMED"
git -C "$A" push -q origin HEAD:main; v "approved commit: push accepted"
# -- Generated views -----------------------------------------------------------
echo "== generated views"
reset_world; mkdir "$A/zz"; printf '# ZZ\n\nnew home\n' > "$A/zz/README.md"; git -C "$A" add zz
! git -C "$A" commit -qm "new home"; v "stale MAP: commit refused"
reset_world; mkdir "$A/zz"; printf '# ZZ\n\nnew home\n' > "$A/zz/README.md"; regen "$A"; git -C "$A" add zz
! git -C "$A" commit -qm "new home"; v "MAP fresh in the tree but stale in the index: refused"
reset_world; mkdir "$A/zz"; printf '# ZZ\n\nnew home\n' > "$A/zz/README.md"; regen "$A"; git -C "$A" add -A
git -C "$A" commit -qm "new home"; v "MAP regenerated and staged: accepted"
# -- The ledger gate -------------------------------------------------------------
echo "== ledger gate"
reset_world; printf '\n## 2026-01-01 — a test decision\n\n**Status:** draft\n\nbody\n' >> "$A/os/decisions.md"
regen "$A"; git -C "$A" add -A
git -C "$A" commit -qm draft; v "append-only: a draft appended without a token is accepted"
reset_world; set_line "$A/os/decisions.md" 1 "# Decisions, edited"; regen "$A"; git -C "$A" add -A
! git -C "$A" commit -qm edit; v "append-only: editing an existing line without a token is refused"
reset_world; printf 'ledger_gate=off\n' > "$A/os/guard.conf"
git -C "$A" commit -qam "ledger gate off
OWNER-CONFIRMED"
set_line "$A/os/decisions.md" 1 "# Decisions, edited"; regen "$A"; git -C "$A" add -A
git -C "$A" commit -qm edit; v "gate off: editing the ledger without a token is accepted"
reset_world; printf 'ledger_gate=typo\n' > "$A/os/guard.conf"
git -C "$A" commit -qam "ledger gate typo
OWNER-CONFIRMED"
set_line "$A/os/decisions.md" 1 "# Decisions, edited"; regen "$A"; git -C "$A" add -A
! git -C "$A" commit -qm edit; v "gate value unknown: fails closed (edit refused)"
# -- Secrets -------------------------------------------------------------------
echo "== secrets"
aws="AKIA$(rand 16 | tr 'a-z' 'A-Z')"
ant="sk-ant-api03-$(rand 93)AA"
reset_world; printf 'a = %s\nb = %s\n' "$aws" "$ant" >> "$A/os/roadmap.md"; git -C "$A" add -A
git -C "$A" commit -qm "secret-shaped" 2> "$W/err"; r=$?
[ "$r" -eq 0 ] && grep -q WARN "$W/err" && grep -q 'sk-ant' "$W/err"; v "no gitleaks: AWS- and Anthropic-shaped keys warn, commit goes through" "$W/err"
if command -v gitleaks >/dev/null 2>&1; then
  reset_world; printf 'token = "%s"\ngh = "ghp_%s"\n' "$ant" "$(rand 36)" >> "$A/os/roadmap.md"; git -C "$A" add -A
  PLAINFRAME_GITLEAKS=on git -C "$A" commit -qm "real-looking keys" 2> "$W/err"; r=$?
  [ "$r" -ne 0 ]; v "gitleaks: a real-looking key blocks the commit" "$W/err"
  ! grep -qF "$ant" "$W/err"; v "gitleaks: the report never prints the value" "$W/err"
else
  echo "SKIP  gitleaks checks (gitleaks not installed)"
fi

# -- Sync: scope -----------------------------------------------------------------
echo "== sync: scope"
reset_world
printf '# mine\n' > "$A/areas/mine.md"
printf 'their half-written page\n' > "$A/areas/other-draft.md"
put_line "$A/areas/README.md" "NOT-YET-SAVED-7Q"
sync_in A "add my page" --receipt "test: mine" -- areas/mine.md
[ "$(rc)" -eq 0 ]; v "path mode: exit 0" "$W/out"
on_origin areas/mine.md; v "path mode: my page is on GitHub"
! on_origin areas/other-draft.md; v "path mode: the other untracked page is not"
! origin_file areas/README.md | grep -q NOT-YET-SAVED-7Q; v "path mode: the other edit is not"
[ -f "$A/areas/other-draft.md" ] && grep -q NOT-YET-SAVED-7Q "$A/areas/README.md" && [ "$(git -C "$A" status --porcelain | wc -l | tr -d ' ')" -eq 2 ]; v "path mode: both other files are still here, untouched"
origin_file os/worklog.md | grep -q 'test: mine' && origin_file os/worklog.md | grep -q ' sync: add my page'; v "path mode: work receipt and sync receipt both on GitHub"
[ "$(git -C "$A" rev-parse HEAD)" = "$(git -C "$W/origin.git" rev-parse main)" ]; v "path mode: this tree sits at GitHub's tip"
(cd "$A" && /bin/bash os/scripts/doctor.sh) > "$W/out" 2>&1
grep -q 'all checks passed' "$W/out"; v "path mode: doctor passes on the result" "$W/out"
reset_world; printf 'x\n' > "$A/areas/a1.md"; printf 'y\n' > "$A/areas/a2.md"
sync_in A "sync everything"
[ "$(rc)" -eq 0 ] && on_origin areas/a1.md && on_origin areas/a2.md && [ -z "$(git -C "$A" status --porcelain)" ]; v "no paths: everything is committed" "$W/out"
reset_world; put_line "$A/CLAUDE.md" "UNSAVED-DRAFT-7Q"; printf 'x\n' > "$A/areas/x.md"
sync_in A "x" -- areas/x.md
[ "$(rc)" -eq 0 ] && on_origin areas/x.md && ! origin_file CLAUDE.md | grep -q UNSAVED-DRAFT-7Q; v "a protected file dirty outside the paths does not block" "$W/out"
reset_world; put_line "$A/CLAUDE.md" "mine"
sync_in A "edit the constitution" -- CLAUDE.md
[ "$(rc)" -eq 1 ] && said BLOCKED; v "a protected path in scope without a token: BLOCKED, exit 1" "$W/out"
reset_world; sync_in A "nothing"
[ "$(rc)" -eq 0 ] && said 'nothing to sync' && [ "$(git -C "$W/origin.git" rev-parse main)" = "$BASE" ]; v "nothing to sync: no commit, no receipt" "$W/out"
reset_world; printf 'z\n' > "$A/areas/z.md"; put_line "$A/os/worklog.md" "2026-01-01 other: RECEIPT-NOT-SYNCED-7Q"
sync_in A "z" --receipt "test: z" -- areas/z.md
[ "$(rc)" -eq 0 ] && ! origin_file os/worklog.md | grep -q RECEIPT-NOT-SYNCED-7Q && tail -n 1 "$A/os/worklog.md" | grep -q RECEIPT-NOT-SYNCED-7Q && origin_file os/worklog.md | grep -q 'test: z'; v "another session's receipt stays here, uncommitted, at the end" "$W/out"
long=$(printf 'w%.0s ' $(seq 1 120))
reset_world; printf 'l\n' > "$A/areas/l.md"; sync_in A "long" --receipt "test: $long" -- areas/l.md
[ -z "$(awk '/^## Last 10 receipts/ { on = 1; next } /^## / { on = 0 } on && length($0) > 170' "$A/STATUS.md")" ]; v "STATUS cuts each receipt to 160 characters"

reset_world; printf 'sp\n' > "$A/areas/with space.md"
sync_in A "space" -- "areas/with space.md"
[ "$(rc)" -eq 0 ] && on_origin "areas/with space.md"; v "a path with a space in its name" "$W/out"
reset_world; printf 'old\n' > "$A/areas/old.md"; sync_in A "add old" -- areas/old.md
rm "$A/areas/old.md"; sync_in A "remove old" -- areas/old.md
[ "$(rc)" -eq 0 ] && ! on_origin areas/old.md && [ -z "$(git -C "$A" status --porcelain)" ]; v "a deleted file in scope: the deletion is synced" "$W/out"
reset_world; put_line "$A/areas/README.md" "STAGED-BY-OTHER-7Q"; git -C "$A" add areas/README.md; printf 'm\n' > "$A/areas/m.md"
sync_in A "m" -- areas/m.md
[ "$(rc)" -eq 0 ] && git -C "$A" diff --cached --name-only | grep -qx areas/README.md && ! origin_file areas/README.md | grep -q STAGED-BY-OTHER-7Q; v "another session's staged change stays staged, and unpushed" "$W/out"
reset_world; put_line "$A/os/worklog.md" "2026-01-01 other: RECEIPT-NOT-SYNCED-7Q"; printf 'u\n' > "$A/areas/untouched.md"
sync_in A "receipt only" --receipt "test: receipt alone" --
[ "$(rc)" -eq 0 ] && origin_file os/worklog.md | grep -q 'test: receipt alone' && ! origin_file os/worklog.md | grep -q RECEIPT-NOT-SYNCED-7Q && ! on_origin areas/untouched.md && tail -n 1 "$A/os/worklog.md" | grep -q RECEIPT-NOT-SYNCED-7Q; v "receipt only (--receipt … --): the receipt alone, nothing else taken" "$W/out"
reset_world; printf 'p\n' > "$B/areas/p.md"; sync_in B "p" -- areas/p.md; tip=$(git -C "$W/origin.git" rev-parse main)
sync_in A "pull only"
[ "$(rc)" -eq 0 ] && said 'pulled:' && [ -f "$A/areas/p.md" ] && [ "$(git -C "$A" rev-parse HEAD)" = "$tip" ] && [ "$(git -C "$W/origin.git" rev-parse main)" = "$tip" ]; v "only GitHub moved: sync pulls it down and writes no receipt" "$W/out"

# -- Template merges ---------------------------------------------------------------
echo "== template merges"
reset_world
git init -q --bare "$W/tpl.git"; git clone -q "$W/origin.git" "$W/T"
put_line "$W/T/CLAUDE.md" "TEMPLATE-RULE-7Q"; git -C "$W/T" commit -q --no-verify -am "template: a kernel change"
git -C "$W/T" push -q --no-verify "$W/tpl.git" HEAD:refs/heads/main
git -C "$A" remote add template "$W/tpl.git"; git -C "$A" fetch -q template
git -C "$A" merge -q --no-ff -m "merge: template update
OWNER-CONFIRMED" template/main && git -C "$A" push -q origin HEAD:main; v "approved template merge: the upstream commit is not re-judged, push accepted"
reset_world; git -C "$A" merge -q --no-ff --no-verify -m "merge: no approval" template/main
! git -C "$A" push -q origin HEAD:main 2>/dev/null; v "template merge with no approval line: push refused"
# UPGRADING.md step 6: merge, then sync — while another session pushes first.
tpl=$(git -C "$A" rev-parse template/main)
reset_world; git -C "$A" merge -q --no-ff -m "merge: template update
OWNER-CONFIRMED" template/main
printf 'b\n' > "$B/areas/b.md"; sync_in B "b" -- areas/b.md
sync_in A "template merged" --receipt "test: template merged" --
m=$(git -C "$W/origin.git" rev-list --merges -n 1 main)
[ "$(rc)" -eq 0 ] && [ -n "$m" ] && [ "$(git -C "$W/origin.git" rev-parse "$m^2")" = "$tpl" ] && on_origin areas/b.md; v "template merge, then GitHub moved: sync keeps the merge, the template commit its second parent" "$W/out"
reset_world; git -C "$A" merge -q --no-ff -m "merge: template update
OWNER-CONFIRMED" template/main
printf 'b\n' > "$B/areas/b.md"; sync_in B "b" -- areas/b.md
(cd "$A" && /bin/bash os/scripts/session-start.sh) > "$W/out" 2>&1
said 'rebased' && [ "$(git -C "$A" rev-parse HEAD^2 2>/dev/null)" = "$tpl" ] && git -C "$A" merge-base --is-ancestor origin/main HEAD; v "template merge, then GitHub moved: session start keeps the merge too" "$W/out"
git -C "$A" remote remove template
# -- Sync: satellites --------------------------------------------------------------
echo "== sync: satellites"
reset_world; printf 'stray\n' > "$W/sat/stray.txt"; printf 's\n' > "$A/areas/s.md"
sync_in A "s" -- areas/s.md
[ "$(rc)" -eq 3 ] && said 'PARTIAL:' && ! said 'OK: synced'; v "dirty satellite: exit 3 and a PARTIAL line, never OK" "$W/out"
on_origin areas/s.md && [ -f "$W/sat/stray.txt" ] && [ "$(git -C "$W/sat" rev-parse HEAD)" = "$SATBASE" ]; v "dirty satellite: main still pushed, satellite untouched"
reset_world; printf 'stray\n' > "$W/sat/stray.txt"; printf 's\n' > "$A/areas/s.md"
sync_in A "s
SATELLITE-CONFIRMED" -- areas/s.md
[ "$(rc)" -eq 0 ] && git -C "$W/sat.git" cat-file -e main:stray.txt; v "SATELLITE-CONFIRMED: the satellite is committed and pushed" "$W/out"
reset_world; printf '# Handoff — sat two\n' > "$W/sat/docs/handoffs/2026-01-02-two.md"
put_line "$A/os/roadmap.md" "- an unrelated line"
git -C "$A" commit -qam unrelated; v "a satellite's new handoff never blocks a commit here"
reset_world; printf 'old\n' > "$W/sat/old.txt"; touch -t 202001010000 "$W/sat/old.txt"; regen "$A"
grep -q 'sat: 1 uncommitted file(s) since 2020-01-01' "$A/DESK.md"; v "DESK names a satellite's day-old uncommitted work"
rm -f "$W/sat/old.txt"
/bin/bash "$A/os/scripts/gen-desk.sh" --check; v "…and that line is live state: --check still passes once it's gone"
# -- Sync: both ways -----------------------------------------------------------------
echo "== sync: both ways"
reset_world
printf 'b\n' > "$B/areas/b.md"; sync_in B "b" --receipt "test: b" -- areas/b.md
printf 'a\n' > "$A/areas/a.md"; sync_in A "a" --receipt "test: a" -- areas/a.md
[ "$(rc)" -eq 0 ]; v "both moved: exit 0" "$W/out"
on_origin areas/a.md && on_origin areas/b.md && [ "$(git -C "$A" rev-list --merges "$BASE..HEAD" | wc -l | tr -d ' ')" -eq 0 ]; v "both moved: GitHub has both pages, history is linear"
[ -f "$A/areas/b.md" ] && [ "$(git -C "$A" rev-parse HEAD)" = "$(git -C "$W/origin.git" rev-parse main)" ]; v "both moved: this tree has the other machine's page and sits at the tip"
origin_file os/worklog.md | grep -q 'test: a' && origin_file os/worklog.md | grep -q 'test: b' && /bin/bash "$A/os/scripts/gen-status.sh" --check; v "both moved: both receipts kept (union merge), STATUS regenerated clean"
reset_world
set_line "$B/areas/README.md" 3 "B's version of this line"; sync_in B "b" -- areas/README.md
set_line "$A/areas/README.md" 3 "A's version of this line"; sync_in A "a" -- areas/README.md
[ "$(rc)" -eq 1 ] && said 'PULL BLOCKED'; v "real conflict: PULL BLOCKED, exit 1" "$W/out"
[ "$(git -C "$A" rev-list --count origin/main..HEAD)" -ge 1 ] && grep -q "A's version" "$A/areas/README.md" && ! [ -d "$A/.git/rebase-merge" ]; v "real conflict: nothing lost — A's commit is here, unpushed, no rebase left open"
[ "$(git -C "$A" worktree list | wc -l | tr -d ' ')" -eq 1 ]; v "no scratch worktree left behind by any sync above, blocked ones included"
reset_world
set_line "$B/areas/README.md" 3 "B changed this"; sync_in B "b" -- areas/README.md
put_line "$A/areas/README.md" "A's unsaved edit"; printf 'y\n' > "$A/areas/y.md"
sync_in A "y" -- areas/y.md
[ "$(rc)" -eq 3 ] && on_origin areas/y.md && grep -q "A's unsaved edit" "$A/areas/README.md"; v "someone's unsaved edit to a file the pull changes: pushed, exit 3, edit untouched" "$W/out"
# -- Session start -----------------------------------------------------------------
echo "== session start"
reset_world; put_line "$B/CLAUDE.md" "a new rule"
git -C "$B" commit -qam "constitution
OWNER-CONFIRMED"; git -C "$B" push -q origin HEAD:main
(cd "$A" && /bin/bash os/scripts/session-start.sh) > "$W/out" 2>&1; r=$?
[ "$r" -eq 0 ] && said 'pulled 1 commit' && said 'CLAUDE.md changed' && [ "$(git -C "$A" rev-parse HEAD)" = "$(git -C "$W/origin.git" rev-parse main)" ]; v "pulls GitHub's side and says CLAUDE.md changed" "$W/out"
reset_world; git -C "$A" remote set-url origin "$W/nowhere.git"
(cd "$A" && /bin/bash os/scripts/session-start.sh) > "$W/out" 2>&1; r=$?
[ "$r" -eq 0 ] && said 'could not reach'; v "offline: says so and still exits 0" "$W/out"
reset_world; printf 'l\n' > "$A/areas/l.md"; git -C "$A" add -A; regen "$A"; git -C "$A" add -A; git -C "$A" commit -qm local
put_line "$A/areas/README.md" "dirty"; printf 'r\n' > "$B/areas/r.md"; sync_in B "r" -- areas/r.md
h=$(git -C "$A" rev-parse HEAD); (cd "$A" && /bin/bash os/scripts/session-start.sh) > "$W/out" 2>&1
said 'not touched' && [ "$(git -C "$A" rev-parse HEAD)" = "$h" ] && grep -q dirty "$A/areas/README.md"; v "diverged with uncommitted edits: reported, nothing touched" "$W/out"
git -C "$A" checkout -q -- areas/README.md
(cd "$A" && /bin/bash os/scripts/session-start.sh) > "$W/out" 2>&1
said 'rebased' && git -C "$A" merge-base --is-ancestor origin/main HEAD; v "diverged and clean: own unpushed commit rebased on top" "$W/out"
echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
