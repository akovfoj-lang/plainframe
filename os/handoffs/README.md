# Handoffs

The session handoff chain. Each file here is one session's parting note to the next.

## Naming

`YYYY-MM-DD-HHMMSS-topic.md` — timestamp first so files sort chronologically, then a short topic slug.

Example: `2026-07-18-143000-first-sweep.md`

## Format

Start from `_templates/handoff.md`. Every handoff carries:

- **Continues from:** a link to the previous handoff. These links form a chain running back through every session — follow it to replay history.
- What was done, what is in flight, the exact next step, and open questions for the owner.

## Rules

- Write handoffs per `os/playbooks/handoff.md`.
- Never rewrite an old handoff. It is a record, not a page.
