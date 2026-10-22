# Routine

The rhythm. The commands are cheap; the habit is the system.

| Cadence | Do | Command |
|---------|----|---------|
| Daily-ish | Drain the inbox while it's small | /sweep |
| Every unit of work | Sync both ways — the session does it itself | sync.sh |
| Weekly (Fri) | 3Ms interview — find and ship one automation | /level-up |
| Monthly | Health report — staleness, drift, flags; can run itself | /audit |

Session bookends, every time:

- **Start:** `os/scripts/session-start.sh` pulls, checks the views and names stuck work —
  Claude Code runs it for you. Then take the task. Full protocol in CLAUDE.md.
- **End:** the session syncs itself (`os/scripts/sync.sh … -- <its paths>`). Add /handoff
  if the work continues next session.

"Daily-ish" means: whenever there's something in the inbox. An empty sweep costs a
minute; a month-old inbox costs an afternoon. If you want a nag, schedule
`os/scripts/drift-alert.sh` — it only notifies, never commits (law 8). Setup lines are
in os/playbooks/sync.md. The monthly audit can be scheduled the same way, report-only
until you say "file it": os/playbooks/audit.md, "Running it by itself every month".
