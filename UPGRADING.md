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
   - **Your content** — `areas/`, `incubator/`, `os/decisions.md`, `os/worklog.md`,
     `inbox/`, `archive/`, `os/handoffs/`, `os/satellites.txt`, `.env.example`. Nothing
     here ships from the template's side (it has no idea what your areas or decisions
     are), so a conflict here means a template update touched a line you also touched —
     keep yours; only pull in the template's version if you can see exactly why it changed
     and want that change.
4. Regenerate everything before committing the merge: `os/scripts/gen-map.sh`,
   `os/scripts/gen-status.sh`, `os/scripts/gen-commands.sh`. A clean merge can still leave
   `MAP.md` or `STATUS.md` stale (their sources moved, they didn't get rebuilt), and the
   pre-commit hook blocks a commit that carries that (law 6).
5. Run `os/scripts/doctor.sh`. Fix anything it flags before committing.
6. Commit the merge, then `/sync` so it's pushed, not stranded on one machine.

## If a generated file itself conflicts

`MAP.md`, `STATUS.md`, and the `.claude/commands/` / `.agents/skills/` adapters are never
hand-edited (law 6) — if git shows a conflict inside one of them, don't resolve it line by
line. Take either side (it doesn't matter which one), then immediately regenerate:

```
os/scripts/gen-map.sh && os/scripts/gen-status.sh && os/scripts/gen-commands.sh
```

The regenerated output is the only version that can be correct either way.

## Version

The current template version is in [VERSION](VERSION) at the repo root; what changed and
when is in [CHANGELOG.md](CHANGELOG.md). Neither file is a protected path — if you fork the
template further and want your own version line, update `VERSION` yourself.
