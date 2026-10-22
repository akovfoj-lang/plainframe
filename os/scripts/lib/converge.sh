# shellcheck shell=bash disable=SC2034  # sourced: CONVERGE_CONFLICTS is read by the caller
# converge.sh — bring a local branch and its GitHub side together, both ways,
# without ever rewriting anything already pushed (law 8). Shared by sync.sh and
# session-start.sh so they settle conflicts by the same rules (law 3).
#
# Sourced, not executed. Provides:
#
#   is_view PATH            true for a generated view (law 6): never hand-merged
#                           — a conflict in one is settled by regenerating it.
#   regen_views DIR         regenerates every view in DIR, a Plainframe tree;
#                           does nothing in a repo without the generators (a
#                           satellite). Exit 2 if a generator fails.
#   add_views DIR           stages every view that exists or is tracked in DIR.
#   upstream_of DIR BRANCH  prints "<remote> <merge-ref>" for BRANCH, nothing
#                           when it has no upstream.
#   quiet_fetch DIR REMOTE  git fetch that never prompts and gives up on a dead
#                           network instead of hanging a session.
#   in_rebase DIR           true while DIR has a rebase in progress.
#   rebase_onto DIR ONTO    rebases DIR's unpushed commits onto ONTO — the one
#                           rewrite the constitution allows: this machine's own
#                           commits, never a pushed one. Views that conflict are
#                           regenerated and the rebase goes on; os/worklog.md
#                           never conflicts (merge=union, .gitattributes). Any
#                           other conflict aborts the rebase cleanly — the tree
#                           is exactly as it was — returns 1, and leaves the
#                           files in CONVERGE_CONFLICTS (PF-033).

is_view() {
  case $1 in
    MAP.md|STATUS.md|DESK.md|.claude/commands/*|.agents/skills/*) return 0 ;;
  esac
  return 1
}

regen_views() {
  [ -f "$1/os/scripts/gen-map.sh" ] || return 0
  (
    cd "$1" || exit 2
    # Order matters: MAP lists DESK.md, so DESK exists before MAP is drawn.
    for rv_g in gen-commands gen-desk gen-map gen-status; do
      [ -f "os/scripts/$rv_g.sh" ] || continue
      /bin/bash "os/scripts/$rv_g.sh" >/dev/null 2>&1 || exit 2
    done
  )
}

add_views() {
  for av_p in MAP.md STATUS.md DESK.md .claude/commands .agents/skills; do
    if [ -e "$1/$av_p" ] || [ -n "$(git -C "$1" ls-files -- "$av_p")" ]; then
      git -C "$1" add -A -- "$av_p"
    fi
  done
}

upstream_of() {
  uo_r=$(git -C "$1" config "branch.$2.remote" 2>/dev/null) || return 0
  uo_m=$(git -C "$1" config "branch.$2.merge" 2>/dev/null) || return 0
  [ "$uo_r" != "." ] || return 0
  printf '%s %s\n' "$uo_r" "$uo_m"
}

quiet_fetch() {
  GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=20 \
    GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=15 -o BatchMode=yes}" \
    git -C "$1" fetch -q "$2" >/dev/null 2>&1
}

in_rebase() {
  (
    cd "$1" || exit 1
    [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]
  )
}

rebase_onto() {
  ro_dir=$1
  ro_onto=$2
  CONVERGE_CONFLICTS=""
  if git -C "$ro_dir" -c rebase.autoSquash=false rebase -q --no-autostash "$ro_onto" >/dev/null 2>&1; then
    return 0
  fi
  ro_n=0
  while in_rebase "$ro_dir"; do
    ro_n=$((ro_n + 1))
    if [ "$ro_n" -gt 200 ]; then
      git -C "$ro_dir" rebase --abort >/dev/null 2>&1 || true
      CONVERGE_CONFLICTS="(the rebase would not settle)"
      return 1
    fi
    ro_conf=$(git -C "$ro_dir" diff --name-only --diff-filter=U)
    ro_bad=$(printf '%s\n' "$ro_conf" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      is_view "$f" || printf '%s\n' "$f"
    done)
    if [ -n "$ro_bad" ]; then
      git -C "$ro_dir" rebase --abort >/dev/null 2>&1 || true
      CONVERGE_CONFLICTS=$ro_bad
      return 1
    fi
    if [ -n "$ro_conf" ]; then
      if ! regen_views "$ro_dir"; then
        git -C "$ro_dir" rebase --abort >/dev/null 2>&1 || true
        CONVERGE_CONFLICTS="(a generator failed while settling: $(printf '%s ' $ro_conf))"
        return 1
      fi
      add_views "$ro_dir"
    fi
    if git -C "$ro_dir" diff --cached --quiet; then
      GIT_EDITOR=true git -C "$ro_dir" rebase --skip >/dev/null 2>&1 || true
    else
      GIT_EDITOR=true git -C "$ro_dir" rebase --continue >/dev/null 2>&1 || true
    fi
  done
  return 0
}
