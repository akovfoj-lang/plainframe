# Upgrading

Your clone starts diverging from the public template the moment you make it yours — real
areas, real decisions, real history. This is how to pull template improvements back into a
clone that has already gone its own way, without losing any of that.

## One-time setup

Add the public template as a second remote, named `template` — never `origin`; `origin`
stays your own private clone:

```
git remote add template https://github.com/akovfoj-lang/plainframe.git
```

## Pulling an update

1. See what changed before merging blind: `git fetch template`, then
   `git log HEAD..template/main --oneline` for the commit list, and read the relevant
   entries in the template's `CHANGELOG.md` (`git show template/main:CHANGELOG.md`) for the
   why behind them.
2. Merge it in: `git merge template/main`. The very first time you ever do this in a given
   clone, git may refuse over unrelated history — add `--allow-unrelated-histories` just
   that once; every merge after the first doesn't need it.
3. Resolve conflicts. Two kinds show up, and they resolve differently:
   - **Kernel files** — `os/scripts/` (incl. `os/scripts/hooks/`), `os/playbooks/`,
     `CLAUDE.md`, `AGENTS.md`, `os/commands.md`. These are meant to converge with
     upstream: unless you deliberately customized the file, prefer the template's side.
     If you did customize it, reconcile by hand and keep your customization.
   - **Your content** — `areas/`, `incubator/`, `workspace/`, `answers/`,
     `os/decisions.md`, `os/worklog.md`,
     `inbox/`, `archive/`, `os/handoffs/`, `os/satellites.txt`, `.env.example`. Nothing
     here ships from the template's side (it has no idea what your areas or decisions
     are), so a conflict here means a template update touched a line you also touched —
     keep yours; only pull in the template's version if you can see exactly why it changed
     and want that change.
4. Regenerate everything before committing the merge: `os/scripts/gen-commands.sh`,
   `os/scripts/gen-map.sh`, `os/scripts/gen-desk.sh`, `os/scripts/gen-status.sh`. A clean
   merge can still leave a view stale (its sources moved, it didn't get rebuilt), and the
   pre-commit hook blocks a commit that carries that (law 6).
5. Run `os/scripts/doctor.sh` and `os/scripts/test.sh`. Fix anything they flag before
   committing.
6. Commit the merge — it changes kernel files, so its message needs the owner's
   `OWNER-CONFIRMED` line, or pre-push refuses it — then sync so it's pushed, not stranded
   on one machine.

## If a generated file itself conflicts

`MAP.md`, `STATUS.md`, `DESK.md`, and the `.claude/commands/` / `.agents/skills/` adapters
are never hand-edited (law 6) — if git shows a conflict inside one of them, don't resolve
it line by line. Take either side (it doesn't matter which one), then immediately
regenerate (sync.sh does this by itself for conflicts it meets):

```
os/scripts/gen-commands.sh && os/scripts/gen-map.sh && os/scripts/gen-desk.sh && os/scripts/gen-status.sh
```

The regenerated output is the only version that can be correct either way.

## Coming from 1.8.0 to 1.8.1

- **A routed block now ends at `<!-- /trust -->`.** /ingest writes it. Blocks routed
  before 1.8.1 have none, so `markers.sh` now tags everything below them on that page as
  `[untrusted origin]`, and /sweep reports those markers instead of acting on them. To
  re-enable the marker track below an old block, add `<!-- /trust -->` under it.
- **A workspace note waits on you only when its `**Blocked on:**` starts with "owner"**,
  as the note template says. "the owner" or "a call from the owner" no longer counts.
- **The command adapters are regenerated** with quoted descriptions; the merge brings
  them, nothing to do.

## Coming from 1.7.0 to 1.8.0

- **Claude Code asks before it edits a protected path**, even in bypass mode, and refuses
  a force-push, `--no-verify` and printing `.env`. If you keep your own
  `.claude/settings.json` hooks, the merge adds `PreToolUse` and `PostToolUse` beside
  them; keep both sides.
- **After a fetch or an MCP call, the session sees one line of law 10 context.** Nothing
  is blocked.

## Coming from 1.6.3 to 1.6.4

- **More counts as protected.** A `CLAUDE.md`, `AGENTS.md`, `.gitignore` or
  `.gitattributes` in any folder, and any protected path in another letter case, now needs
  `OWNER-CONFIRMED`, like the root ones. A clone with no such nested files sees no change.
- **With `ledger_gate=append-only`, a new ledger entry needs `**Status:** draft`,
  spelled exactly so** — the spelling DESK lists as waiting. Any other Status line, or an
  entry with none, needs the token. With `ledger_gate=off` nothing changes.
- **An amend is judged against its parent.** Fixing your own unpushed draft no longer
  needs the token; an amend that drops an approval is refused at commit time instead of at
  push.

## Coming from 1.6.2 to 1.6.3

- **A second workflow arrives, switched off.** `.github/workflows/check-private.yml` runs
  the same checks on Linux only, when the kernel changes and once a week — a few minutes
  a month. It does nothing until you opt in:
  `gh variable set PLAINFRAME_PRIVATE_CI --body linux`. The `workflow` token scope note
  under 1.6.1 applies to this merge too.
- **Three answers from sync change.** A tree mid-merge (or rebase, cherry-pick, revert,
  or with unresolved conflicts) is BLOCKED instead of committed. A branch with no
  upstream ends PARTIAL instead of OK. And paths after `--` are literal and relative to
  where you run it, so run from the repo root, as the playbook says, and nothing changes.

## Coming from 1.6.0 to 1.6.1

- **The merge brings a workflow file**, `.github/workflows/check.yml`, and GitHub refuses
  to take one from a token without the `workflow` scope ("refusing to allow an OAuth App
  to create or update workflow"). Before you push the merge, check `gh auth status`; if
  `workflow` is not among the token scopes, run `gh auth refresh -h github.com -s workflow`
  and approve it in the browser.
- **It costs a private clone nothing.** The job runs on public repos only; in a private
  clone GitHub lists it as skipped.

## Coming from 1.5.x to 1.6.0

- **Your customized guards become a setting.** If you removed the ledger's append-only
  gate from `guard.sh`, `commit-msg` and `sync.sh` (as some clones did), take the
  template's side of those three files and put `ledger_gate=off` in `os/guard.conf`
  instead — your choice now lives in one data line, and the next update merges cleanly.
- **A new hook, already wired.** `pre-push` sits in `os/scripts/hooks/` beside the other
  two, so a clone that ran `doctor.sh --setup` has it the moment the merge lands. Commits
  any remote already holds are never judged again, so old history cannot block a push.
- **Sync changes shape, not meaning.** `sync.sh "<msg>"` with no paths behaves as before
  — it commits everything. Pass `-- <paths>` to commit only those, and `--receipt` to
  carry the work's receipt; it writes its own `sync:` receipt now, so the second
  hand-run pass in the old playbook is gone. Exit 3 means `PARTIAL`.
- **Claude Code runs session start for you.** `.claude/settings.json` adds a SessionStart
  hook; Claude Code may ask you once to trust the project's hooks. Other agents run
  `os/scripts/session-start.sh` themselves (AGENTS.md step 1).
- **Optional: gitleaks.** `brew install gitleaks` (macOS) turns the secret check from a
  warning into a real scan that blocks. Nothing else to install.

## Version

The current template version is in [VERSION](VERSION) at the repo root; what changed and
when is in [CHANGELOG.md](CHANGELOG.md). Neither file is a protected path — if you fork the
template further and want your own version line, update `VERSION` yourself.
