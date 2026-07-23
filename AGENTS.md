# AGENTS.md — start here

Identical rules for every agent, whichever tool you are (Claude, Codex/GPT, anything future).
There is no separate rulebook.

One term recurs everywhere below: **the owner** is the human running this repo — as
opposed to you, the agent operating it. Every "the owner" in these docs means that person,
never you.

1. `git pull --ff-only` first — before reading `CLAUDE.md`, so the constitution you're about
   to read can't be stale (law 8). If a later pull in this session changes `CLAUDE.md`
   (e.g. during `/sync`), re-read it in full before continuing — "read once" means once per
   fresh copy, not once no matter what the tree does underneath you.
2. **Read `CLAUDE.md` next, then `MAP.md`**, and follow only the pages MAP routes you to.

Tool-specific command adapters live in `.claude/commands/` (Claude Code, native) and
`.agents/skills/` (Codex, native — other agents can still run Plainframe by reading the
playbooks in `os/playbooks/` directly, just without a generated command surface yet; see
README's "One repo, many agents"). Both generated sets come from `os/commands.md` — the
playbooks are the single source of truth. If your adapters and the manifest disagree,
regenerate: `os/scripts/gen-commands.sh`.

The kernel holds nothing tool-specific. Same repo, same laws, interchangeable operators.
