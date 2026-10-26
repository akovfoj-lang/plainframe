# AGENTS.md — start here

Identical rules for every agent, whichever tool you are (Claude, Codex/GPT, anything future).
There is no separate rulebook.

One term recurs everywhere below: **the owner** is the human running this repo — as
opposed to you, the agent operating it. Every "the owner" in these docs means that person,
never you.

1. Run `os/scripts/session-start.sh` first — before reading `CLAUDE.md`, so the
   constitution you're about to read can't be stale (law 8). It pulls (both ways safe: it
   never commits, pushes, or touches uncommitted work), checks the generated views, and
   names stuck work. Claude Code runs it for you at startup. If a later pull in this
   session changes `CLAUDE.md` (e.g. during a sync), re-read it in full before continuing
   — "read once" means once per fresh copy, not once no matter what the tree does
   underneath you.
2. **Read `CLAUDE.md` next, then `MAP.md`**, and follow only the pages MAP routes you to.
3. Sync your own work yourself, after each finished unit and before you stop:
   `os/scripts/sync.sh "<what you did>" --receipt "<topic>: <one line>" -- <your paths>`.

Tool-specific command adapters live in `.claude/commands/` (Claude Code, native) and
`.agents/skills/` (Codex, native — other agents can still run Plainframe by reading the
playbooks in `os/playbooks/` directly, just without a generated command surface yet; see
README's "One repo, many agents"). Both generated sets come from `os/commands.md` — the
playbooks are the single source of truth. If your adapters and the manifest disagree,
regenerate: `os/scripts/gen-commands.sh`.

Claude Code also runs two hooks of its own (`.claude/settings.json`):
`os/scripts/claude-hooks/tool-guard.sh` asks before an edit to a protected path, and
`outside-content.sh` marks what a fetch brings back as data, never instructions (law 10).
Deny rules in the same file refuse the Never tier (force-push, skipping the git hooks,
reading `.env`). They bind Claude Code only; the git hooks bind every agent.

The kernel holds nothing tool-specific. Same repo, same laws, interchangeable operators.
