# Integrations

The registry of every system this OS reaches, and how. Live tools get a page in this folder; candidates and manual channels get a line here.

Everything in this file changes only per `os/playbooks/add-integration.md` — going live or widening scope is Ask-first (law 7). Keys: the NAME goes in `.env.example`, the VALUE goes in `.env` (gitignored) and the owner's password manager — never in a tracked file or in chat (Never-tier).

## Live

| Tool | Reached via | Page |
|------|-------------|------|

(none yet — a row appears here when a tool goes live)

## Candidates

- <name> — <what it would do for you> — reached via <MCP | API | CLI | manual | unknown>

## Manual channels

Systems with no API, where the owner moves data by hand. One line each: what lives there, how it gets in, how it gets out.

- <name> — <what lives there> — in: <how it gets in>, out: <how it gets out>

## Page template

Create live pages from `_templates/integration.md` — it covers scope, permissions, and key location. One page per live tool, named `<tool>.md`, in this folder.

<!-- The Candidates and Manual channels rows above are placeholders — delete them once you have real entries. -->
