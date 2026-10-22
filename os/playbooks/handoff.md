# Handoff

Write the session handoff so the next session starts exactly where this one ended.

1. Write one when any of these hits: the session is ending, context is running heavy, or a milestone just landed.
2. Copy `_templates/handoff.md` into `os/handoffs/`.
3. Name it `YYYY-MM-DD-HHMMSS-topic.md` — timestamp first, then a short topic slug.
4. Fill it in: what was done, what is in flight, the exact next step, open questions for the owner.
5. Link the previous handoff under "Continues from" — the links form a chain back through every session (see `os/handoffs/README.md`).
6. Sync it, so it is pushed, not stranded on one machine: `os/scripts/sync.sh "handoff: <topic>" --receipt "handoff: <summary>" -- <the handoff's path>`. Sync regenerates STATUS.md and DESK.md — DESK names the newest handoff in each chain, so it goes stale the moment you write one.

Receipt: the `--receipt` above — `YYYY-MM-DD handoff: <summary>` in os/worklog.md.
