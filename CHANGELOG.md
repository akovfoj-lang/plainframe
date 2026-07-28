# Changelog

All notable changes to the Plainframe template, newest first. Dates are when the work
landed in the template's own history — not necessarily when it reaches a given private
clone (see [UPGRADING.md](UPGRADING.md) for that). Commit hashes point at this repo's
history for anyone who wants the full diff behind a line.

Versioning starts at 1.0.0 with this file: everything below predates `VERSION` existing,
and is backfilled here for the record rather than split across version numbers that were
never actually cut at the time.

## [1.3.0] — 2026-07-27

### Added

- **`workspace/` — the missing middle of the capture pipeline.** One file per question the
  owner is actively deciding, carrying `status: open | settled`. Plainframe already had
  `inbox/` (unsorted), `incubator/` (might become something) and `os/decisions.md`
  (decided), but nothing held a question mid-argument — so those questions lived in chat
  and died there, and the reasoning behind a ledger entry was never written down anywhere.
  A note lists the options with what each costs and buys, where the thinking currently
  leans, and — the load-bearing field — **what would settle it**. A question that cannot
  name what would settle it is not ready for `workspace/`; that test is what stops the
  folder becoming a second inbox. When settled, the call is appended to `os/decisions.md`
  as a draft (law 2) and the note moves to `archive/`, so the thinking stays readable while
  the decision keeps one home (law 3). Shape in `_templates/workspace-note.md`.

- **`answers/` — questions looked up once, kept honestly.** One file per researched
  question, phrased as a question, with a short answer capped at three sentences (if it
  needs more, it was two questions). Every entry carries `**Checked:**` and
  `**Re-check when:**` — an answer with no expiry is a claim pretending to be a fact.
  Distinct from `references/`, which holds third-party documents shipped intact; this is
  the owner's own answer in their own words. Distinct from `os/decisions.md`, which records
  what was *chosen* rather than what is *true* — an answer that settled a call links to the
  ledger entry rather than restating it (law 3). Answers arrive from outside, so law 10
  applies: record what a source said, never adopt what it told you to do. Shape in
  `_templates/answer.md`.

### Changed

- `os/scripts/gen-status.sh` reports both new homes: `## Workspace` counts notes by
  `status:` line exactly as `## Incubator` does, and `## Answers` reports a item count.
  Both use the same NUL-delimited enumeration as the incubator block (PF-020), so a
  filename containing a newline stays one record. Neither count is volatile, so `--check`
  stays stable.
- `os/playbooks/sweep.md` routes two further destinations: open questions to `workspace/`,
  looked-up facts to `answers/` — each with the test that keeps items out of the wrong
  home.
- `os/playbooks/guide.md` describes the four capture homes as one pipeline that moves left
  to right as a thing firms up, rather than as four independent piles.
- `README.md`'s loop diagram and `UPGRADING.md`'s "your content" conflict class both name
  the new homes.

## [1.2.0] — 2026-07-24

### Added

- **`/level-up`, the eighth command** — a weekly (Friday) 3Ms interview — Mindset (find
  the candidate) → Method (scope one) → Machine (build it) — that ships one automation
  per run (`os/playbooks/level-up.md`). This is third-party content from
  [AIS-OS](https://github.com/nateherkai/AIS-OS) (MIT, © 2026 Nate Herk), shipped
  verbatim on the owner's explicit choice, attribution intact — the two attribution
  blockquotes, the closing trademark line, and the `three-ms-attribution` scaffolding
  block all survive unedited. The complete list of changes, and nothing else:
  (1) the upstream YAML frontmatter replaced by an `# Level up` H1 plus a provenance
  note; (2) six input paths remapped to Plainframe's homes — `context/priorities.md` →
  `os/roadmap.md`, `context/about-me.md` → `profile.md`, `connections.md` →
  `os/integrations/README.md`, `decisions/log.md` → `os/decisions.md`,
  `.claude/skills/*/SKILL.md` → `.agents/skills/*/SKILL.md`, and
  `audits/audit-{date}.md` → `archive/audit-YYYY-MM-DD.md`
  (`references/3ms-framework.md` needed no remap — that path is correct here too);
  (3) every ledger write reworded to append as `**Status:** draft` for the owner to
  confirm (`os/decisions.md` is a protected, byte-exact append-only ledger — law 2);
  (4) the `profile.md` input marked "if present", since a clone has none until
  `/onboard` runs; (5) the scaffolded-artifact location made explicit as
  `.agents/skills/<name>/SKILL.md`, noting PF-017 leaves unmarked user files untouched
  through regeneration; and (6) a closing receipt line (law 9). No prose, heading,
  question, table row, or section of the upstream text was altered or removed.
- **`references/3ms-framework.md`** — the Three Ms of AI™ framework doc `/level-up`
  reads to quote principles back, copied byte-for-byte from AIS-OS with no edits at all.
- **`references/`** — a new top-level home for third-party reference material, with its
  own `README.md` and routed in `MAP.md`.
- **`THIRD-PARTY-NOTICES.md`** — what was taken from AIS-OS, where from, and the
  complete upstream MIT licence text verbatim, including the reserved "Three Ms of AI™"
  trademark notice. Routed in `MAP.md` right after `UPGRADING.md`.
- **`os/routine.md`** gained a weekly (Friday) row for `/level-up`, alongside the
  existing daily-ish/weekly/monthly rhythm.

## [1.1.0] — 2026-07-24

### Added

- **`/onboard`, the seventh command** — a resumable, idempotent setup interview
  (`os/playbooks/onboard.md`) that configures a fresh clone into the owner's own instance:
  asks what the OS is for and who the owner is, scaffolds `areas/<slug>/README.md` for each
  area named, seeds `os/roadmap.md`'s priorities, records reachable systems in
  `os/integrations/README.md`, and writes `profile.md` from the new
  `_templates/profile.md`. Cross-linked with `/guide` (`/guide` explains the system and
  reads nothing back; `/onboard` configures it and leaves a receipt).
- **`_templates/profile.md`** — the template `/onboard` writes `profile.md` from; not
  itself shipped, since a fresh clone has no `profile.md` until `/onboard` runs.
- **`profile.md` routed in `MAP.md`** — `os/scripts/gen-map.sh`'s root-files loop lists it
  right after `CLAUDE.md` once it exists (law 1); absent on a fresh clone, it is skipped
  like any other missing root file.
- **Reachability folded into the integrations registry** — `os/integrations/README.md` now
  tracks how each Live tool and Candidate is reached (MCP / API / CLI / manual), and gained
  a "Manual channels" section for systems with no API at all.
  `os/playbooks/add-integration.md` updated to match.

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
