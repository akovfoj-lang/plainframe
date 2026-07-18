# Routine

The rhythm. The commands are cheap; the habit is the system.

| Cadence | Do | Command |
|---------|----|---------|
| Daily-ish | Drain the inbox while it's small | /sweep |
| Weekly | Persist everything: pull → commit → push | /sync |
| Monthly | Health report — staleness, drift, flags | /audit |

Session bookends, every time:

- **Start:** pull, glance at STATUS.md, take the task. Full protocol in CLAUDE.md.
- **End:** /sync. Add /handoff if the work continues next session.

"Daily-ish" means: whenever there's something in the inbox. An empty sweep costs a
minute; a month-old inbox costs an afternoon. If you want a nag, schedule
`os/scripts/drift-alert.sh` — it only notifies, never commits (law 8). Setup lines are
in os/playbooks/sync.md.
