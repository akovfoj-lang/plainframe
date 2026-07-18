# AGENTS.md — start here

Identical rules for every agent, whichever tool you are (Claude, Codex/GPT, anything future).
There is no separate rulebook: **read `CLAUDE.md` next, then `MAP.md`**, and follow only the
pages MAP routes you to.

Tool-specific command adapters live in `.claude/commands/` (Claude) and `.agents/skills/`
(other agents). Both sets are **generated** from `os/commands.md` — the playbooks in
`os/playbooks/` are the single source of truth. If your adapters and the manifest disagree,
regenerate: `os/scripts/gen-commands.sh`.

The kernel holds nothing tool-specific. Same repo, same laws, interchangeable operators.
