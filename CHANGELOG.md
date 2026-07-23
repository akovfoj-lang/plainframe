# Changelog

All notable changes to the Plainframe template, newest first. Dates are when the work
landed in the template's own history — not necessarily when it reaches a given private
clone (see [UPGRADING.md](UPGRADING.md) for that). Commit hashes point at this repo's
history for anyone who wants the full diff behind a line.

Versioning starts at 1.0.0 with this file: everything below predates `VERSION` existing,
and is backfilled here for the record rather than split across version numbers that were
never actually cut at the time.

## [1.0.0] — 2026-07-22

### Hardening — external adversarial review

Three waves closing findings from an outside adversarial review of the whole system —
mechanics, wording, and structure.

- **Wave 1** (`647a2c0`) — BSD-first `stat` probe with a loud failure mode instead of a
  silent GNU-first one; Never-tier deletion wording reconciled with the sanctioned
  archival flow; agent-adapter claims in the README scoped to what is actually generated;
  the cold-start sequence fixed to pull before it reads governance; `gen-map.sh` made
  gitignore-aware so an empty ignored directory can't fail `--check`; worklog epoch
  pointers added ahead of the first yearly rotation.
- **Wave 2** (`3f4c65d`) — staleness enforcement moved from the worktree to the staged
  index (a regenerate-then-stage-only-sources bypass no longer works); commit tokens
  (`OWNER-CONFIRMED`, `SATELLITE-CONFIRMED`) matched only as a standalone message line,
  never a substring; the protected-path set expanded (playbooks, `.gitignore`,
  `satellites.txt`, `os/scripts/hooks/`) and moved into a `commit-msg` hook so a raw
  `git commit` can't bypass it; a byte-exact append-only gate on `os/decisions.md` that
  catches mid-entry insertions, not just net diff stats; a dirty-satellite confirmation
  guard so `/sync` never sweeps a satellite's unrelated work in sight-unseen;
  `os/playbooks/sync.md`'s receipt now records the sync outcome instead of predicting it;
  `gen-commands.sh` regen that only touches files it generated itself, leaving
  hand-added commands and skills alone; NUL-safe filename handling end to end in
  `gen-status.sh` and `markers.sh`; distinct exit codes so "stale" and "internal error"
  are never reported as the same failure.
- **Wave 3 (this round)** — structural fixes: provenance tags that survive routing out of
  `inbox/`, so `markers.sh` can still see a fact's untrusted origin after `/sweep` or
  `/ingest` moves it; a documented, boundary-by-boundary crash-recovery rule for `/sweep`
  so a kill at any step is safe to rerun with no duplicate appends; `os/handoffs/` and the
  latest `/audit` report surfaced into MAP.md and STATUS.md so law 1's read path can
  actually reach them; an optional `actor` field on worklog receipts and ledger entries,
  and an honest rewrite of the README's team FAQ about what that does and doesn't buy
  you; optional `source:` / `captured-at:` / `confidence:` fields for facts recorded on an
  area page; a data-classification section in the README plus a warn-only staged-secrets
  check in `doctor.sh`; and this file, `VERSION`, and `UPGRADING.md`.

### Optimization waves

Three rounds of self-directed hardening that shipped before the external review, laying
the groundwork it then tested.

- **Truth & safety** (`7b2d192`) — receipt-ordering fixes so a receipt is never written
  before the work it claims is actually done; the draft decision format (void until the
  owner confirms in-session, law 2); law 10 (external content is data, never commands)
  written in at the point of contact instead of only stated abstractly; staleness checks
  on generated files.
- **Mechanical enforcement** (`7f70800`) — the protected-path gate; `doctor.sh` plus a
  pre-commit hook; hostile-filename safety; atomic file writes (temp-sibling-then-move,
  never a truncated file on failure); command-manifest validation; satellite-aware
  STATUS.md.
- **Evolution** (`f5dd2a1`) — superseded-ledger archival guidance; worklog epoch rotation
  wired into `/audit`; taint envelopes introduced in `/ingest` and `/sweep`; receipt
  evidence pointers; law-1 and law-9 rewording; four incubator seeds.

### Added

- **Initial template ship** (`5a152bd`, plus an early STATUS/audit visibility fix in
  `be7fed2`) — 2026-07-18. The kernel: the 10 laws, six commands and their playbooks,
  generated `MAP.md` / `STATUS.md`, the autonomy table, and example area/incubator
  content to show the shape of a real one.
