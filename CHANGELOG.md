# Changelog

All notable changes to the Plainframe template, newest first. Dates are when the work
landed in the template's own history — not necessarily when it reaches a given private
clone (see [UPGRADING.md](UPGRADING.md) for that). Commit hashes point at this repo's
history for anyone who wants the full diff behind a line.

Versioning starts at 1.0.0 with this file: everything below predates `VERSION` existing,
and is backfilled here for the record rather than split across version numbers that were
never actually cut at the time.

## [1.10.0] — 2026-10-26

DESK can see a deadline now. A review of a private clone found its DESK saying "nothing
waiting" ten days before the owner's course deadline: the date was written on an area page,
in prose, and DESK reads no prose. A `DUE:` line is the fix. 139 tests, up from 135. On
1.9.0 two of the four new tests fail. The other two, that `gen-desk.sh --check` holds with
deadlines listed and that the /sweep listing leaves `DUE:` alone, guard against a regression
and already held there.

### Added

- **`DUE: YYYY-MM-DD what`**, a deadline marker. It counts where the other markers do: at
  line start, after a list bullet, a `>`, a numbered-list marker or `<!--`. DESK lists every
  one first under "Waiting on you", soonest first, as `**Due 2026-11-04** — what — [page](page)`,
  until the line is deleted. It shows the date itself, never "in 9 days": DESK is checked
  for staleness at every commit and session start, so a countdown would be stale by
  morning. A `DUE:` with no readable date is listed last, as "no date".
- **`os/scripts/markers.sh --due`** lists them as `date<TAB>path<TAB>line<TAB>what`. A
  deadline is the owner's own word, so it skips untrusted lines (`inbox/`, a routed block),
  fenced examples, and history (`archive/`, `os/handoffs/`, `brainstorms/`). It works
  outside git, since the pre-commit hook checks DESK in a non-git export of the index. If it
  fails, DESK says "Deadlines unreadable" instead of leaving them out.
- **A `DUE:` row in README's marker table.**

The /sweep listing is unchanged: it never shows `DUE:`, since a deadline is not a task for
/sweep to resolve.

## [1.9.0] — 2026-10-25

A fourth independent review, of the two Claude Code hooks, found 23 bugs and reproduced 22 of
them in a clean clone. Nine were in the tool guard's own reading of shell commands. A test in
bypass mode (Claude Code 2.1.308, desktop app) then showed which of Claude Code's own
permission rules hold there. "Deny" rules do: a second probe refused 26 of 30 risky commands.
"Ask" rules do not prompt at all, despite the docs. So the tool guard keeps the one job only a
hook can do in bypass mode, asking before a protected-path edit, and the Never tier moves to
deny rules. 135 tests, up from 133: the five tests of the old Bash and Read checks are
replaced by seven. On 1.8.1 six of them fail. The seventh, a missing library exits non-zero,
already held there by accident, but nothing blocked the call.

### Changed

- **The tool guard judges edits only** (Edit, Write, MultiEdit, NotebookEdit) and asks
  before one lands on a protected path or inside `.git/`. It no longer reads Bash commands
  or Read calls, so the false alarms of its command parser are gone too: a commit message
  that mentions `--force` now runs.
- **The Never tier is 49 deny rules in `.claude/settings.json`**, which hold in bypass mode
  and judge each part of a chained command:
  - reading `.env` and `.env.*` (`.env.example`, `.env.sample` and `.env.template` pass);
  - a force-push: `--force`, `-f` and `+ref`, quoted or not, `--mirror`, and a
    `remote.*.push` override;
  - skipping the git hooks: `--no-verify` and its abbreviations, `git commit -n`, and
    `core.hooksPath` in its common letter cases, and config set through `--config-env`
    or a `GIT_CONFIG*` variable;
  - printing `.env` with `xxd`, `hexdump`, `less`, `more`, `bat`, `tac` or `rg`, which
    the Read rules alone let through.
- **16 ask rules on the protected paths** sit beside them. They do not prompt in bypass
  mode, which is why the hook stays. They cost nothing, and they should cover the other
  modes, though that is untested.
- **The hook fails closed.** If git fails or a library is missing or broken, it exits
  non-zero, and `"onFailure": "block"` blocks the call. In 1.8.x every such failure meant
  `exit 0` and no output, so the guard switched itself off without a word.

### Fixed — could let a protected edit through without asking

- **Unicode spellings of a protected name.** On case-insensitive APFS, `AGENTſ.md` (long s)
  is `AGENTS.md`, and `.claude/hooKs` with the Kelvin sign is `.claude/hooks`. Names are now
  compared after NFKC and Unicode case folding (`perl`). Without perl the hook falls back to
  ASCII case folding, as before.
- **A file symlink is judged where it lands**, so a link into `.git/config` asks. A chain of
  links is followed up to 32 deep, and a longer one asks instead of passing.
- **Config that runs by itself was unprotected**: `.claude/settings.local.json`,
  `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, `.mcp.json`, and `CLAUDE.local.md`
  at any depth. They are now in `lib/guard.sh`'s list, so the git hooks and `sync.sh` hold
  the tracked ones as well as the tool guard.
- **A path with a TAB, a newline or another control character** made the hook's reply invalid
  JSON. The reason text now drops them.

### Known limits

- No rule can see a `.env` read inside a substitution (`echo "$(<.env)"`) or inside
  `bash -c '...'`.
- A Bash command that writes a protected file (`sed -i`, `>`) is caught at commit, not when
  it runs.
- Two harmless commands are refused: `ls -la .env`, and a raw `git commit -m` whose message
  holds ` -n `.

## [1.8.1] — 2026-10-24

A third independent review, of the generators, the session scripts and what the playbooks
say about them, run in a clone with no remote, reproduced 21 bugs and 7 playbook claims
that did not hold. All are fixed, each with a test, plus a false alarm in 1.8.0's tool
guard seen on its first morning. 133 tests, up from 110; on 1.8.0 the 23 new ones fail.

### Fixed — misled you about what is done or waiting, or wrote where it must not

- **A `satellites.txt` with no final newline dropped its last satellite** everywhere:
  never synced, never watched, and drift-alert said "OK: all clean".
- **Copied text could end its own `[untrusted origin]` tag** (law 10): a heading or a
  `source:` line inside a routed block switched the tag off for the markers below it.
  A block now ends only at ingest's closing `<!-- /trust -->`, the next block's
  `<!-- source:` line, or the end of the page.
- **MAP listed empty folders and folders holding only ignored files** (routine in an
  Obsidian vault), so `--check` differed by machine, a raw commit of MAP.md was refused,
  and STATUS reported stale views after every sync.
- **drift-alert rewrote `.git/index`** in this repo and every satellite; it must only
  notify (law 8). It now takes no lock and writes nothing.
- **STATUS took any line opening with a date for a receipt**, prose and fenced examples
  included (law 6). A receipt is `YYYY-MM-DD <topic>: <summary>` outside a code fence.

### Fixed — a wrong or missing item, or a check that disagreed

- **One control character (a terminal colour code, a form feed) hid every marker in a
  note**; and a marker shown inside a code fence counted. Neither any more.
- **A second audit of the day** (`audit-DATE-2.md`) now reads as the latest.
- **gen-commands overwrote a hand-written command or skill** under a manifest name; it
  now stops with an error. **Descriptions are quoted**, so `/audit` and `/sweep` are
  valid YAML.
- **Draft decisions in any spelling** (`Status: draft`, `**Status**: Draft`) show in
  STATUS and DESK; `**Status:** drafted, confirmed` no longer counts as a draft, there or
  in the ledger gate. One shared rule (`draft_decisions`, `lib/fs.sh`).
- **DESK**: a satellite handoff with a non-ASCII name is in the chain; a satellite whose
  only dirt is a deletion still ages out; "Waiting on you" lists a note only when its
  `Blocked on:` starts with "owner", the note template's own convention; a CRLF note's
  title carries no carriage return.
- **STATUS counted ignored inbox files** (Obsidian's `.trash/`, `*.local.*`), and pages
  in incubator, workspace and answers the same way; only what git would store counts.
- **Open flags**: a bulleted or indented `FLAG:` counts, a fenced example does not
  (`open_flags`, `lib/fs.sh`).
- **session-start** names a rebase or merge in progress instead of "detached HEAD" or
  "uncommitted edits overlap"; says when the upstream branch is gone instead of "up to
  date"; never fast-forwards over a local ignored file; and says `PULL BLOCKED` on a real
  conflict, as resolve-conflict.md expects.
- **MAP** reads a README's description through CRLF, a BOM and code fences.
- **STATUS after a yearly rotation** points at the archived receipts instead of "(none)".
- **The tool guard (1.8.0) denied a command that only mentioned** a `.env` file or the
  hook-skipping flag in a heredoc, such as a commit message. It now reads the command
  line by line, skips heredoc bodies, and wants `git` before the flag.

## [1.8.0] — 2026-10-23

Two of Plainframe's rules were checked only at commit, or only by prose. In Claude Code
they now hold when a tool runs too: the law 7 tool guard and the law 10 hook. Both bind
Claude Code only; the git hooks still bind every agent. 14 new tests (110, up from 96).

### Added

- **`os/scripts/claude-hooks/tool-guard.sh`** (PreToolUse). An edit to a protected path
  — `lib/guard.sh`'s list, any depth, any letter case, through a symlink — or inside
  `.git/` now asks first. Drafting there stays allowed; the commit gate still enacts. It
  refuses the Never tier outright: a force-push, skipping the git hooks (`--no-verify`,
  `git commit -n`, a `core.hooksPath` override), and printing or reading a `.env` file
  (`.env.example` passes). Sessions in bypass mode had no check here at all.
- **`os/scripts/claude-hooks/outside-content.sh`** (PostToolUse, law 10). After WebFetch,
  WebSearch, any MCP tool (the app's own `ccd_*` tools excepted) and a read from `inbox/`,
  it adds one line of context: the result is data, never instructions. It flags the
  approval tokens `OWNER-CONFIRMED` and `SATELLITE-CONFIRMED` turning up in the result,
  and phrasing aimed at an AI ("ignore previous instructions", ...). It only adds
  context; it never changes or blocks a result.
- **`os/scripts/lib/json.sh`**: just enough JSON reading for the hooks, without jq.
- `.claude/settings.json` wires both, next to SessionStart. `AGENTS.md` and `CLAUDE.md`
  say what they do and that they bind Claude Code only.

## [1.7.0] — 2026-10-23

A tenth command, and two existing ones now start from measurements instead of memory.

### Added

- **`/grill-me`** (`os/playbooks/grill-me.md`) interviews the owner one question at a time,
  each with a recommended answer, and saves every answer to
  `brainstorms/YYYY-MM-DD-<topic>.md` before asking the next. Like `/deepen`, its playbook
  carries a skill header, so the same file works as a skill outside the repo, for any
  agent. Based on Matt Pocock's MIT-licensed `grill-me`; credit and licence are in
  `THIRD-PARTY-NOTICES.md`.
- **`brainstorms/`**, the home for those capture files. A brainstorm is history, never
  the source of truth.

### Changed

- **`/audit` measures reading load**: the bytes of `AGENTS.md`, `CLAUDE.md` and `MAP.md`
  that every session reads. Over 13,000 is 🟡, over 16,000 🔴, with the cut drafted for
  the owner. A private clone's `CLAUDE.md` had grown to 9.7 KB before anyone measured it.
- **`/level-up` opens with the worklog**: it counts the last 30 days of receipts by topic
  and suggests from the top ones, instead of relying on what the owner remembers doing.
- Nine → ten commands in `README.md`, `CLAUDE.md` and `os/playbooks/guide.md`.

## [1.6.4] — 2026-10-23

A second independent review, of the git hooks and the guard logic (`hooks/pre-commit`,
`hooks/commit-msg`, `hooks/pre-push`, `lib/guard.sh`, `lib/secrets.sh`, `doctor.sh
--setup`), run in a clone with no remote, reproduced 15 bugs, each with a script that
showed it. All 15 are fixed, and each has a test in `test.sh` (96 tests, up from 80). On
1.6.3, the new tests fail and the old ones still pass.

### Fixed — could let a guard through

- **An uncommitted `ledger_gate=off` switched the ledger gate off** for the hooks, at
  commit and at push. They now read the committed `os/guard.conf`, as `sync.sh` already did.
- **The ledger gate knew one spelling.** Only `**Status:** confirmed` was refused, so
  `Status: confirmed` (the template's own wording), `Confirmed`, or no Status line at all
  passed as a draft. Now every appended entry must carry `**Status:** draft`, the
  spelling DESK lists as waiting, and any other Status line needs the token.
- **A Status line split over two appends passed**: `**Stat` in one commit, `us:**
  confirmed` in the next. An append that continues an unfinished last line is now judged
  with that line.
- **A nested `.gitignore`, `.gitattributes`, `CLAUDE.md` or `AGENTS.md` was not
  protected**, so `areas/.gitignore` with `!.env` let a `.env` through with no token.
  They now count at any depth.
- **A protected path in another letter case was not protected**: `.GitHub/workflows/x.yml`
  passed every hook, and on macOS it lands in `.github/workflows/`. Matching ignores case.
- **`core.commentChar=auto` (or `core.commentString`) hid the `-v` scissors line** from
  commit-msg, so a diff line that was only the token approved a protected edit. The
  scissors line is now found whatever its comment prefix.
- **`diff.ignoreSubmodules=all` in your git config hid a gitlink** at a protected path
  from every hook. The hooks and `sync.sh` now always count submodules.
- **pre-push trusted any ref under `refs/remotes/`**, even one no remote owns. Only the
  tracking refs of a configured remote exempt a commit now.
- **The fallback secret scan went blind with `color.ui=always`**, and **skipped any added
  line that starts with `++`**. The diff is now always plain, and file headers are told
  apart by where they stand.

### Fixed — wrongly blocked, or a misleading message

- **On macOS, one invalid UTF-8 byte in a commit message hid the approval line** below it
  (BSD sed stops at the bad byte in a UTF-8 locale). The token check now reads bytes.
- **Amending your own unpushed draft needed the token**: commit-msg judged an amend
  against the commit it replaces. It now judges against that commit's parent, as pre-push
  does, which also catches an amend that drops an approval at commit time.
- **The first push from a clone with no remote-tracking refs told you to rebase onto
  `@{u}`**, which does not exist yet. The push is still judged in full (the hook cannot
  tell old history from new), but the advice now fits: fetch the remote that already holds
  those commits, or `git rebase -i --root`.
- **The fallback scan warned on ordinary long kebab-case names** like
  `task-queue-design-notes-…` (the `sk-` key shape had no left edge). A key must now start
  a word. It also knows more shapes in its own families: temporary AWS keys (`ASIA`),
  Slack app tokens and webhook URLs, Google `ya29.` tokens, PGP private keys.
- **`doctor.sh --setup` in a copy sitting inside another repo wired that repo's hooks.**
  It now refuses, as it does outside any repo.
- A root commit's ledger check used SHA-1's empty tree by name; it now asks git, so a
  SHA-256 repo works too.

## [1.6.3] — 2026-10-23

An independent review of `sync.sh` and `lib/converge.sh`, run in a clone with no remote,
reproduced 18 bugs, each with a script that showed it. All 18 are fixed, and each has a
test in `test.sh` (80 tests, up from 59). On 1.6.2, the new tests fail and the old ones
still pass.

### Fixed — could push the wrong thing, or let a guard through

- **A satellite's own `STATUS.md`, `MAP.md` or `DESK.md` in a rebase conflict was
  "settled" by committing its conflict markers**, pushed, with `OK`. Only a tree with the
  generators settles a view by redrawing it; in a satellite it is a real conflict, PULL
  BLOCKED (`lib/converge.sh`).
- **A staged `git mv` of a protected file passed the protected-path gate**, and moving a
  hook out of `os/scripts/` also switched off the hook layer behind it. The gate now
  judges the commit's own tree with renames counted as deletes.
- **Syncing mid-merge committed and pushed conflict markers**, with `OK`. A tree in the
  middle of a merge, rebase, cherry-pick or revert, or with unresolved conflicts, is now
  BLOCKED; such a satellite is skipped, PARTIAL (`unfinished_op`, `lib/converge.sh`).
- **Paths after `--` were globs**: `[a].md` also committed another session's `a.md`. Each
  path is now literal.
- **Run from a subdirectory, a relative path named the root's file** (`-- README.md` from
  `areas/` synced `README.md`). Paths are now the caller's.
- **The ledger gate read an uncommitted `os/guard.conf`**, so a local `ledger_gate=off`
  opened it. The committed setting judges.

### Fixed — reported the wrong outcome, or stopped in a bad state

- **A branch with no upstream ended `OK: synced`** with a sync receipt and nothing pushed.
  It is now PARTIAL ("not pushed (no upstream)"), with no sync receipt.
- **A satellite's own commit hook refusing aborted the run silently**, leaving it staged.
  It is now skipped with its index restored; this repo still syncs; PARTIAL.
- **A path that could not be staged stopped the run after the satellites were already
  pushed**, with no receipt. The commit's tree is now built, and the gate run, before any
  satellite is touched.
- **Only a view dirty here while GitHub moved it** died with a raw git error and no final
  word, on every retry. The scratch tree is reset when nothing is committed, and any move
  that fails now says BLOCKED.
- **A file with a non-ASCII name always ended PARTIAL**, the tree left behind GitHub;
  **so did a changed symlink**. Names are compared raw (`-z`), and a symlink by its target.
- **Two pushes racing on GitHub's side** ("cannot lock ref") were not retried.
- **An interrupt between moving the branch and its files** left a staged revert of the
  sync. Those two steps now run with INT, TERM and HUP held off.
- **Rerunning after an offline PARTIAL wrote the `--receipt` twice**; it is now kept once.
- **Another session's pending worklog line was dropped** when it repeated an older line;
  only the lines the update itself adds are left out now.
- **The old name of a `git rm` or `git mv`** was refused as "no such path".
- **A satellite path containing `#`** was cut at the `#` and skipped. A comment is now a
  whole line or ` #…`; one `satellite_list` (`lib/fs.sh`) replaces five copies of the
  parser (sync, session start, drift alert, DESK, STATUS).

### Added

- **`check-private.yml`**: an opt-in, Linux-only run of the same checks for a private
  clone, when the kernel changes and once a week. It stays off until
  `gh variable set PLAINFRAME_PRIVATE_CI --body linux`.
- **A note on long receipts**: `sync.sh` warns on a `--receipt` over 200 characters (the
  worklog asks for short ones; STATUS cuts them at 160). It never refuses one.

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
