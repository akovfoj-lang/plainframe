# Changelog

All notable changes to the Plainframe template, newest first. Dates are when the work
landed in the template's own history — not necessarily when it reaches a given private
clone (see [UPGRADING.md](UPGRADING.md) for that). Commit hashes point at this repo's
history for anyone who wants the full diff behind a line.

Versioning starts at 1.0.0 with this file: everything below predates `VERSION` existing,
and is backfilled here for the record rather than split across version numbers that were
never actually cut at the time.

## [1.6.2] — 2026-10-22

### Fixed

- **A sync could take a template merge apart.** When both sides had moved, `sync.sh` and
  `session-start.sh` rebased this machine's unpushed commits with a plain `git rebase`,
  which drops a merge commit and replays the merged-in commits as new ones. So the merge
  UPGRADING.md step 6 has a clone make, then sync, came apart whenever GitHub moved in
  between — another session pushing first was enough: the template's commits came back as
  the clone's own, without their approval line, pre-push refused them, and the sync
  stopped BLOCKED with this tree's branch already moved onto the flattened copy (the merge
  survived only in the reflog). `rebase_onto` (`os/scripts/lib/converge.sh`) now moves
  only the first-parent line and redoes each merge against its own other parents,
  untouched, so the template's commits keep their hashes and stay unjudged.
  `--rebase-merges` alone was not enough: it still rebases a side branch rooted at the
  fork point. Two new tests in `test.sh` make a template merge, let another clone push
  first, then sync (and, separately, start a session), and check the merge survives with
  the template commit as its second parent.
- **A rebase that never started passed for a finished one.** `rebase_onto` returned
  success whenever no rebase was left open, even when none had begun (a file in the way,
  a git too old for the todo), and sync went on to push into a refusal. It now checks that
  the result sits on top of GitHub's side, and says PULL BLOCKED when it does not.
- **`resolve-conflict.md` no longer rebases a merge by hand.** Step 3's `git rebase @{u}`
  had the same flaw as sync; with a merge among the local commits, step 4 (merge) applies.

## [1.6.1] — 2026-10-22

### Added

- **CI on macOS and Linux** (`.github/workflows/check.yml`): every push to main and every
  pull request runs doctor, ShellCheck at warning level and the end-to-end tests on both
  systems. 1.6.0 had passed on macOS only; the workflow was held back because the token
  that pushed the release could not write workflows. It runs on public repos only: a
  private clone pays for Actions minutes (macOS at 10x), and every sync pushes to main, so
  there the job is skipped and costs nothing.

### Fixed

- **`test.sh` hung forever on GitHub's macOS runner.** The runner starts each step with
  SIGPIPE ignored, and its `rand` helper piped `/dev/urandom` through `tr` into `head`:
  once `head` had its characters and hung up, BSD `tr` kept reading and never exited (GNU
  `tr` stops, so Linux passed). `rand` now reads a bounded 4 KB and cuts, so nothing in the
  pipe depends on SIGPIPE. Linux needed no fixes: the GNU/BSD fallbacks in `lib/fs.sh` and
  `gen-status.sh` held on the first run.

## [1.6.0] — 2026-10-22

A full review of a real clone, three months and 400 commits in, found the machinery sound
(every check green, ShellCheck clean, no secret in any commit) and the trouble in how
syncing worked around people: an owner typing /sync by hand every time, sessions sharing
one tree, satellites, two machines. This release makes the session sync itself, both ways,
and closes the gaps a throwaway-clone attack found in the guards.

### Added

- **The session syncs itself** (CLAUDE.md law 8, END protocol). After each finished unit of
  work and before it ends, the session runs sync without being asked; /sync is only for
  "sync everything now".
- **`os/scripts/session-start.sh`**, run by Claude Code at every startup
  (`.claude/settings.json`, a SessionStart hook) and by any other agent as its first
  command. It pulls, says when CLAUDE.md changed, checks the views, and names uncommitted
  or stuck work, with its age. A tool that loads CLAUDE.md for the agent could never honor
  "pull before reading this file" before (PF-039).
- **Path-scoped sync** (PF-030): `sync.sh "<msg>" --receipt "<line>" -- <paths>` commits only
  those paths, plus the regenerated views. The commit is built in a scratch worktree from
  HEAD plus the paths, and the shared tree is then moved onto it without touching anyone
  else's files: another session's half-written page, or its unsynced receipt, stays exactly
  where it was. In the review, an untracked draft from "another session" landed in the
  next sync's commit; it cannot now.
- **Sync both ways** (PF-033): fast-forward when only GitHub moved; when both moved, rebase
  this machine's own unpushed commits on top — never a pushed commit, never a merge, never
  a force-push. Conflicted views are regenerated, `os/worklog.md` merges by union
  (`.gitattributes`), and only a real content conflict stops it — with the local commit
  kept, unpushed, nothing lost.
- **Sync writes its own receipt** (PF-034): one call does the work commit, the push, then
  the `sync:` receipt once the outcome is known. 35% of the reviewed clone's commits were
  hand-run receipt passes.
- **`os/scripts/hooks/pre-push`** (PF-037): judges every outgoing commit by its stored
  message, so an approval line amended away, or a commit made with `--no-verify`, no longer
  reaches GitHub. Commits any remote already holds are never re-judged.
- **`os/guard.conf`** (PF-040): the ledger's gate is now a protected one-line setting —
  `ledger_gate=append-only` (default) or `off` — instead of code a clone deletes. A typo
  fails closed.
- **DESK.md comes upstream** (`os/scripts/gen-desk.sh`, PF-041): the one page to open when
  you sit down — what's waiting on you, each project's next step, where every handoff chain
  left off. It now names a satellite whose uncommitted work is more than a day old (one in
  the review sat unsynced, on one disk, for 23 days), and lists open questions only.
- **`os/scripts/test.sh`** (PF-042): 57 end-to-end checks in throwaway repos — a fake
  GitHub, two machines, a satellite, an upstream template — covering every guard, every
  sync path (spaces, deletions, another session's staged work, receipt-only, pull-only)
  and the generators. Run it with doctor and ShellCheck before any kernel change
  (`.github/CONTRIBUTING.md`).
- **The audit's Decision health check**: each confirmed ledger entry added or changed since
  the last report is checked for the owner's own words, for reach beyond what they said, for
  loosening the constitution, and — on every entry — for drift. Fixes are proposed in the
  report; the ledger is never edited by the audit.
- **The audit can run by itself every month**, report-only: a scheduled run writes nothing,
  asks "Want to file it?", and files only on the owner's word in that run
  (`os/playbooks/audit.md`).
- `os/README.md`, so MAP describes the kernel instead of "(no README)".

### Changed

- **Skipped satellites end `PARTIAL`, exit 3** (PF-031), never `OK: sync complete`.
- **Secrets** (PF-035): with gitleaks installed, the pre-commit hook blocks a staged secret,
  values redacted; doctor fails on one. The fallback pattern now also knows Anthropic,
  OpenAI, GitHub and Google API keys, and still only warns.
- **STATUS cuts each receipt to 160 characters** (PF-038). Ten full receipts were 91% of a
  page read at every session start.
- **MAP** lists DESK.md, prints a root file's name once ("AGENTS.md — start here"), and
  three home descriptions got shorter.
- /onboard wires the hooks (`doctor.sh --setup`); /handoff, /audit and /onboard sync their
  own paths with a receipt; the sync, routine and conflict pages describe the new flow.
- More protected paths: `os/guard.conf`, `.gitattributes`, `.claude/settings.json`,
  `.github/workflows/`.

### Fixed

- **`git commit -v` could approve itself** (PF-036): commit-msg read the raw message file,
  diff included, so a diff line that was only the token counted as approval. It now stops
  at git's scissors line and skips comment lines.
- **A satellite's new handoff blocked every commit here** (PF-032): DESK's check compared
  satellite chains strictly, and read uncommitted files. Satellite lines are now live state
  (ignored by `--check`, as STATUS already did), and chains count committed handoffs only.
- A sync with nothing to do no longer commits a STATUS-only change.
- `drift-alert.sh` exits cleanly if it cannot enter the repo; ShellCheck runs clean at
  warning level.

## [1.5.1] — 2026-10-15

### Fixed

- **`/deepen` no longer makes the task bigger.** Its first live test, "write a 20-second
  cold-call opener", came back asking for three variants, objection replies, a pre-dial
  checklist and tracking columns, and quietly cut the 20 seconds to 12, against its own
  "deeper, not bigger" rule. The rewrite now locks the deliverables first (each output,
  how many, its limits), asks for exactly that list, puts the depth into how the output
  is made, and turns the outside check into an acceptance test instead of a new
  artefact. Moves that would add an output are marked **(separate)** and moves that would
  change a limit **(your call)**; both go in one "Not in the prompt, your call" line
  after the prompt. Rerun on the same task, it asked for one 20-second opener and listed
  the extras on that line.

## [1.5.0] — 2026-10-15

### Added

- **`/deepen`, the ninth command** (`os/playbooks/deepen.md`). Give it any task, typed
  before or after `/deepen`, and it hands back the deeper version a top professional
  would do instead of doing the task: it names the field, what that professional would
  do that wasn't asked for, the rawest material they would start from, the named methods
  and tools, and an outside check that would show the result is right. Then it rewrites
  the prompt to ask for exactly that and stops for "go". Deeper, not bigger: a line that
  adds a deliverable instead of raising the standard of the existing one gets cut.
- **The first playbook that is also a portable skill.** `deepen.md` opens with a skill
  header kept to `name` and `description`, the two fields claude.ai's skill upload
  accepts, so the same file can be linked into `~/.claude/skills/` or zipped and
  uploaded to a Claude account. The other playbooks keep their plain `# Title` opening.

### Changed

- Eight → nine commands in `README.md`, `CLAUDE.md` and `os/playbooks/guide.md`. Older
  CHANGELOG entries keep their historical wording.

## [1.4.1] — 2026-09-30

Found by the first `/audit` run in a live clone: its report and the STATUS line summing
it disagreed, and the disagreement traced back to how STATUS reads the tree.

### Fixed

- **STATUS counts one audit verdict per check (PF-026).** `gen-status.sh` counted every
  line of the latest report that contained 🔴 or 🟡, so a summary line or a quoted example
  inflated the totals: a report with 1 red and 4 yellow checks read as 3 red, 6 yellow.
  It now reads one verdict per section heading, the worst when a heading carries more
  than one, and says a report is unreadable rather than printing a clean 0/0 when no
  heading carries a verdict.
- **A mis-shaped receipt is flagged instead of vanishing (PF-027).** The receipt list
  sees only dated lines at column 0, so a receipt written as a bullet or indented fell out
  of STATUS silently, and `--check` still passed. It now shows under Open flags with its
  line number. It is a flag, not a `--check` failure: a mis-shaped record is something to
  straighten, not a reason to block every commit.
- **Inbox age reads the envelope's `captured-at:` (PF-028).** Age came from file
  modification time, which a clone, checkout or copy resets, so an old capture read as
  fresh: this repo's own welcome note, captured 2026-07-18, showed as 14 days old. The
  envelope date now wins; file time is the fallback for an item without one.
- **`/audit`'s generated-files check covers every generator (PF-029).** It ran only
  `gen-map.sh --check` and `gen-status.sh --check`, skipping `gen-commands.sh` and any
  generator a clone adds. It now runs every `os/scripts/gen-*.sh --check`. Step 1 also
  says where a verdict goes: in the check's section heading, which is what STATUS reads.

### Added

- **`_templates/README.md`.** MAP listed `_templates/` as "(no README)"; it now routes
  there by purpose like every other home.

## [1.4.0] — 2026-08-01

### Added

- **`/sweep` resolves markers, instead of only listing them.** `EDIT:` / `Q:` / `IDEA:`
  markers were collected by beat 1 and then silently dropped: the Apply beat only ever
  drained `inbox/`, so a marker typed into a page was surfaced once and abandoned, and the
  same markers re-appeared on every future run. Sweep now has two tracks. The inbox track
  keeps its numbering (steps 7–11) untouched; the marker track is lettered M1–M5 so nothing
  renumbers. `IDEA:` seeds `incubator/`, an answerable `Q:` is answered in place or filed to
  `answers/`, an undecidable one becomes a `workspace/` note, and a clear `EDIT:` is applied.
- **Step 12, "Report back" — the run ends by telling the owner what needs them.** Queue
  first: every marker and inbox piece the sweep would not decide alone, each with its file,
  its text, and one reason — *needs your judgment*, *protected path*, *outward-facing*,
  *untrusted origin*, *not a repo-owned page*, *looks already resolved*, or *may already be
  applied*. Queued markers are left unrouted, unreceipted and uncleared, so the next sweep
  raises them again; the report is how the owner hears about them now, not the only record.

### Changed

- `os/scripts/markers.sh` scans **untracked-but-not-ignored files**, not just tracked ones
  (PF-021). A note typed into Obsidian is untracked until the next `/sync`, so the most
  ordinary marker there is — one written minutes ago — was invisible to the command meant to
  collect it. `--exclude-standard` keeps `.gitignore`'d paths out, so `.env*` is still never
  read; `.trash/` joins `.gitignore` because resurfacing a marker from a note the owner
  deleted is worse than missing it.
- **Markers count after bullets, quotes, numbered items and indentation** (PF-022), not only
  at column 0. Obsidian auto-continues a list on Enter, so the natural way to type a marker —
  under an existing bullet — produced silence, which is indistinguishable from "considered
  and dismissed". The rule is now documented in `README.md`, where the owner reads it, rather
  than only in the script.
- **`trust: data` taint is block-scoped, not file-scoped** (PF-023). A single routed fact
  landing in an area page used to mark the whole file unverified, which permanently disabled
  the marker track for exactly the pages that receive routed facts. Taint now runs from the
  `trust: data` line to the next heading or the next `source:` line.
- **The `[untrusted origin]` tag is decided per file and baked in at emit time** (PF-024). It
  was re-derived from the emitted `path:line:text` record by cutting at the first `:` — but a
  path may legally contain a colon (`inbox/2026-07-31 10:15 clipped.md`), and the truncated
  key matched nothing, silently dropping the tag. A dropped tag reads as "the owner wrote
  this", which is the law-10 breach the tag exists to prevent.
- **One `awk` pass replaces two processes per file** (PF-025): 24.5s → 0.9s on a
  2000-note vault. Binary suppression is now file-level, matching the `grep -I` it replaced,
  and tests for control characters rather than non-printables so UTF-8 prose — em dashes,
  curly quotes, accents, emoji — is not mistaken for a binary and dropped.
- `os/playbooks/sweep.md`'s crash-recovery section covers the marker track. Two rules carry
  it: M5 clears only what *this run* resolved, and M2's already-done checks key on
  *(file, marker text)* and never authorise a delete. A false match therefore costs one line
  of report, where deleting on a grep would have destroyed a duplicate question outright —
  the Never tier's "deleting content before it is durably routed+receipted".
- `os/commands.md`'s `/sweep` description, and with it both generated adapter sets and
  `README.md`'s command table, name what the command now does.
- `os/playbooks/guide.md`, `README.md` and `_templates/area.md` describe the marker track,
  the new `swept-marker:` provenance line, and what `trust: data` now switches off.

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
