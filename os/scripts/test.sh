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
[ "$(rc)" -eq 0 ] && said 'keep receipts to about 200' && origin_file os/worklog.md | grep -qF "test: $long"; v "a long receipt: warned, still written whole" "$W/out"
reset_world; printf 's\n' > "$A/areas/s.md"; sync_in A "short" --receipt "test: short" -- areas/s.md
[ "$(rc)" -eq 0 ] && ! said 'keep receipts to about 200'; v "a short receipt: no warning" "$W/out"

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
# -- Sync: hard cases (the 1.6.3 review, one test per finding) ---------------------
echo "== sync: hard cases"
reset_world; git clone -q "$W/sat.git" "$W/sat2"
printf 'their side\n' > "$W/sat2/STATUS.md"; git -C "$W/sat2" add -A; git -C "$W/sat2" commit -qm theirs; git -C "$W/sat2" push -q origin main
printf 'this side\n' > "$W/sat/STATUS.md"; git -C "$W/sat" add -A; git -C "$W/sat" commit -qm mine; rm -rf "$W/sat2"
printf 's\n' > "$A/areas/s.md"; sync_in A "s" -- areas/s.md
[ "$(rc)" -eq 1 ] && said 'PULL BLOCKED' && ! git -C "$W/sat.git" show main:STATUS.md | grep -q '^<<<<<<<'; v "a satellite's own STATUS.md in conflict: PULL BLOCKED, never settled with markers" "$W/out"
reset_world; git -C "$A" mv CLAUDE.md CONSTITUTION.md
sync_in A "rename" -- CLAUDE.md CONSTITUTION.md
[ "$(rc)" -eq 1 ] && said 'protected paths changed' && on_origin CLAUDE.md; v "a staged git mv of a protected file: BLOCKED" "$W/out"
reset_world; git -C "$A" mv os/scripts/hooks/commit-msg areas/commit-msg
sync_in A "hooks" -- os/scripts/hooks areas/commit-msg
[ "$(rc)" -eq 1 ] && said 'protected paths changed' && on_origin os/scripts/hooks/commit-msg; v "a staged git mv of a hook out of os/scripts: BLOCKED, the hook stays" "$W/out"
reset_world
git -C "$A" checkout -qb side; put_line "$A/areas/c.md" side; git -C "$A" add -A; git -C "$A" commit -q --no-verify -m side
git -C "$A" checkout -q main; put_line "$A/areas/c.md" main; git -C "$A" add -A; git -C "$A" commit -q --no-verify -m main
git -C "$A" merge side >/dev/null 2>&1; printf 'n\n' > "$A/areas/n.md"
sync_in A "notes" -- areas
[ "$(rc)" -eq 1 ] && said 'middle of a merge' && ! on_origin areas/c.md; v "mid-merge: BLOCKED, the conflict markers never leave" "$W/out"
git -C "$A" merge --abort; git -C "$A" branch -qD side
reset_world; printf 'p\n' > "$B/areas/p.md"; sync_in B "p" -- areas/p.md
put_line "$A/STATUS.md" "a stale line"; sync_in A "pull"
[ "$(rc)" -eq 0 ] && [ -f "$A/areas/p.md" ] && [ "$(git -C "$A" rev-parse HEAD)" = "$(git -C "$W/origin.git" rev-parse main)" ]; v "only a view dirty here, and GitHub moved it: pulled, exit 0" "$W/out"
reset_world; printf '1\n' > "$A/areas/café.md"; sync_in A "add" -- "areas/café.md"
put_line "$A/areas/café.md" 2; sync_in A "edit" -- "areas/café.md"
[ "$(rc)" -eq 0 ] && [ -z "$(git -C "$A" status --porcelain)" ] && [ "$(git -C "$A" rev-parse HEAD)" = "$(git -C "$W/origin.git" rev-parse main)" ]; v "a non-ASCII file name: synced, this tree clean at the tip" "$W/out"
reset_world; git -C "$A" branch -q --unset-upstream; printf 'u\n' > "$A/areas/u.md"
sync_in A "u" -- areas/u.md
[ "$(rc)" -eq 3 ] && said 'main not pushed (no upstream)' && ! on_origin areas/u.md && ! grep -q ' sync: u ' "$A/os/worklog.md"; v "no upstream: PARTIAL, exit 3, no sync receipt" "$W/out"
git -C "$A" branch -q --set-upstream-to=origin/main
reset_world; printf 'lit\n' > "$A/areas/[a].md"; printf 'not mine\n' > "$A/areas/a.md"
sync_in A "literal" -- "areas/[a].md"
[ "$(rc)" -eq 0 ] && on_origin "areas/[a].md" && ! on_origin areas/a.md; v "paths are literal: [a].md never sweeps in a.md" "$W/out"
reset_world; put_line "$A/areas/README.md" "SUBDIR-EDIT-7Q"; put_line "$A/README.md" "ROOT-DRAFT-7Q"
(cd "$A/areas" && /bin/bash ../os/scripts/sync.sh "from areas" -- README.md) > "$W/out" 2>&1; echo $? > "$W/rc"
[ "$(rc)" -eq 0 ] && origin_file areas/README.md | grep -q SUBDIR-EDIT-7Q && ! origin_file README.md | grep -q ROOT-DRAFT-7Q; v "run from a subdirectory: a relative path is that directory's file" "$W/out"
reset_world; printf 'g\n' > "$A/areas/gone.md"; printf 'o\n' > "$A/areas/old.md"; sync_in A "add" -- areas/gone.md areas/old.md
git -C "$A" rm -q areas/gone.md; git -C "$A" mv areas/old.md areas/new.md
sync_in A "rm and mv" -- areas/gone.md areas/old.md areas/new.md
[ "$(rc)" -eq 0 ] && ! on_origin areas/gone.md && ! on_origin areas/old.md && on_origin areas/new.md; v "the old names of a git rm and a git mv are accepted" "$W/out"
reset_world; printf 'stray\n' > "$W/sat/stray.txt"; printf 'X=1\n' > "$A/.env.local"
sync_in A "env
SATELLITE-CONFIRMED" -- .env.local
[ "$(rc)" -eq 2 ] && [ "$(git -C "$W/sat.git" rev-parse main)" = "$SATBASE" ]; v "a path that cannot be staged stops the run before any satellite is pushed" "$W/out"
rm -f "$A/.env.local"
reset_world; printf 'o\n' > "$A/areas/o.md"; git -C "$A" remote set-url origin "$W/nowhere.git"
sync_in A "o" --receipt "test: offline once" -- areas/o.md
git -C "$A" remote set-url origin "$W/origin.git"
sync_in A "o" --receipt "test: offline once" -- areas/o.md
[ "$(rc)" -eq 0 ] && [ "$(origin_file os/worklog.md | grep -c 'test: offline once')" -eq 1 ]; v "rerun after an offline PARTIAL: the receipt is written once" "$W/out"
reset_world; ln -s README.md "$A/areas/current"; sync_in A "link" -- areas/current
rm "$A/areas/current"; ln -s ../README.md "$A/areas/current"; sync_in A "relink" -- areas/current
[ "$(rc)" -eq 0 ] && [ -z "$(git -C "$A" status --porcelain)" ]; v "a changed symlink: synced, this tree clean" "$W/out"
reset_world; sync_in A "first" --receipt "test: same words twice" --
put_line "$A/os/worklog.md" "$(grep 'test: same words twice' "$A/os/worklog.md")"
printf 'd\n' > "$A/areas/d.md"; sync_in A "d" -- areas/d.md
[ "$(rc)" -eq 0 ] && [ "$(grep -c 'test: same words twice' "$A/os/worklog.md")" -eq 2 ] && [ "$(origin_file os/worklog.md | grep -c 'test: same words twice')" -eq 1 ]; v "another session's pending line that repeats an older one survives" "$W/out"
reset_world; set_line "$A/os/guard.conf" 1 "ledger_gate=off"; set_line "$A/os/decisions.md" 1 "# Rewritten"
sync_in A "ledger" -- os/decisions.md
[ "$(rc)" -eq 1 ] && said 'protected paths changed'; v "an uncommitted ledger_gate=off does not open the ledger gate" "$W/out"
reset_world; git clone -q "$W/sat.git" "$W/sat#2"; printf '%s\n' "$W/sat#2" > "$A/os/satellites.txt"
printf 'h\n' > "$W/sat#2/h.txt"; printf 'm\n' > "$A/areas/m.md"
sync_in A "m
SATELLITE-CONFIRMED" -- areas/m.md
[ "$(rc)" -eq 0 ] && git -C "$W/sat.git" cat-file -e main:h.txt; v "a satellite path with # in it is read whole" "$W/out"
rm -rf "$W/sat#2"
# Two git stand-ins: a push that loses the race on GitHub's side once, and an
# interrupt (to sync.sh and the git it runs) just as this tree's files move —
# SIGTERM, since a test run in the background has SIGINT ignored already.
REALGIT=$(command -v git); mkdir -p "$W/shim-lock" "$W/shim-int"
cat > "$W/shim-lock/git" <<EOF
#!/bin/bash
if [ "\$1" = -C ] && [ "\$3" = push ] && [ ! -e "$W/shim-lock/lost" ]; then
  : > "$W/shim-lock/lost"
  echo "remote: error: cannot lock ref 'refs/heads/main': is at 1111 but expected 2222" >&2
  echo " ! [remote rejected] HEAD -> main (failed to update ref)" >&2
  exit 1
fi
exec "$REALGIT" "\$@"
EOF
cat > "$W/shim-int/git" <<EOF
#!/bin/bash
if [ "\$1" = read-tree ] && [ "\$2" = -m ] && [ ! -e "$W/shim-int/hit" ]; then : > "$W/shim-int/hit"; kill -TERM \$PPID; kill -TERM \$\$; sleep 2; fi
exec "$REALGIT" "\$@"
EOF
chmod +x "$W/shim-lock/git" "$W/shim-int/git"
reset_world; printf 'k\n' > "$A/areas/k.md"
(cd "$A" && PATH="$W/shim-lock:$PATH" /bin/bash os/scripts/sync.sh "k" -- areas/k.md) > "$W/out" 2>&1; echo $? > "$W/rc"
[ "$(rc)" -eq 0 ] && [ -e "$W/shim-lock/lost" ] && on_origin areas/k.md; v "a push that lost the race on GitHub's side (cannot lock ref) is retried" "$W/out"
reset_world; printf 'q\n' > "$A/areas/q.md"
(cd "$A" && PATH="$W/shim-int:$PATH" /bin/bash os/scripts/sync.sh "q" --receipt "test: q" -- areas/q.md) > "$W/out" 2>&1; echo $? > "$W/rc"
[ -e "$W/shim-int/hit" ] && [ "$(rc)" -eq 0 ] && [ -z "$(git -C "$A" diff --cached --name-only)" ] && [ "$(git -C "$A" rev-parse HEAD)" = "$(git -C "$W/origin.git" rev-parse main)" ]; v "an interrupt while this tree moves: branch and files still move together" "$W/out"
reset_world; mkdir -p "$W/sat-hooks"; printf '#!/bin/sh\necho "satellite policy: no commits today" >&2\nexit 1\n' > "$W/sat-hooks/pre-commit"
chmod +x "$W/sat-hooks/pre-commit"; git -C "$W/sat" config core.hooksPath "$W/sat-hooks"
printf 'n\n' > "$W/sat/new.md"; printf 'p\n' > "$A/areas/p.md"
sync_in A "p
SATELLITE-CONFIRMED" -- areas/p.md
[ "$(rc)" -eq 3 ] && said 'its commit was refused' && on_origin areas/p.md && [ -z "$(git -C "$W/sat" diff --cached --name-only)" ]; v "a satellite's own hook refuses: skipped, its index as it was, this repo still synced" "$W/out"
git -C "$W/sat" config --unset core.hooksPath
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
