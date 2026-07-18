# Decisions

The ledger. This page outranks every other page in the repo (law 2). The newest dated
entry on any topic wins. An entry only counts once the owner has confirmed it in-session —
an agent-appended decision nobody approved is void.

New entries go at the bottom, using the format in `_templates/decision.md`. Never edit an
old entry to reverse a call; add a new dated entry that supersedes it instead.

---

## 2026-07-18: Plain text over an app

**Decision:** Plainframe is a git repo of markdown files, not an app, database, or SaaS
product.

**Why:** Markdown files are readable by any agent, any editor, any human, forever, with
no server to keep alive and no schema migration to run. The read path (law 1) only works
if the whole system is small enough to read — a database hides its own shape.

**Alternatives considered:** A local database (Sqlite) — rejected, adds a dependency and
a query layer agents would need to learn. A hosted app — rejected, single point of
failure and the opposite of "any agent can open it."

**Status:** confirmed

## 2026-07-18: MAP.md and STATUS.md are generated, never hand-written

**Decision:** `os/scripts/gen-map.sh` and `os/scripts/gen-status.sh` are the only things
allowed to write `MAP.md` and `STATUS.md` (law 6).

**Why:** A hand-maintained map goes stale the first time someone forgets to update it
after moving a file, and a stale map is worse than no map — it actively misroutes the
next session's read path. Generation from the actual filesystem and the actual worklog
means the map can't lie about what exists, and STATUS can't lie about what's done.

**Alternatives considered:** Hand-edited MAP.md with a "please keep updated" comment —
rejected, this is exactly the failure mode being designed against. A pre-commit hook that
blocks manual edits — rejected as unnecessary complexity; `--check` mode on the generators
catches drift without needing a hook.

**Status:** confirmed

## 2026-07-18: Scheduled automation is notify-only

**Decision:** Any cron job, launchd task, or scheduled agent run touching this repo may
only read and report (via `drift-alert.sh`). It may never commit, push, or pull-with-merge
on its own.

**Why:** A robot running unattended has no way to judge whether a half-written page is
safe to commit. Committing is a judgment call about completeness; only a session with an
owner or an agent mid-task should make that call (law 8).

**Alternatives considered:** Auto-commit on a timer — rejected, guarantees an eventual
half-written commit. Auto-commit with a "safe" heuristic (e.g. only if `git diff` is
small) — rejected, size doesn't imply safety, and the false confidence is worse than no
automation.

**Status:** confirmed
