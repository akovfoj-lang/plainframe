# Handoff

Write the session handoff so the next session starts exactly where this one ended.

1. Write one when any of these hits: the session is ending, context is running heavy, or a milestone just landed.
2. Start it: `os/scripts/new-handoff.sh <topic-slug>`. It copies `_templates/handoff.md` into `os/handoffs/` as `YYYY-MM-DD-HHMMSS-<topic-slug>.md` — timestamp first — fills in "Saved as", and links the previous handoff under "Continues from", so the links form a chain back through every session (see `os/handoffs/README.md`). Its last line is the new file's path.
3. Fill it in: a title in words, what was done, what is in flight, the exact next step, open questions for the owner.
4. Sync it, so it is pushed, not stranded on one machine: `os/scripts/sync.sh "handoff: <topic>" --receipt "handoff: <summary>" -- <the handoff's path>`. Sync regenerates STATUS.md and DESK.md — DESK names the newest handoff in each chain, so it goes stale the moment you write one.
5. Reply to the owner with the handoff's path first, as a link. The path is all the next session needs, so it never sits under a summary.

Receipt: the `--receipt` above — `YYYY-MM-DD handoff: <summary>` in os/worklog.md.
