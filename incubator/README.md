# Incubator

Ideas in development: one file per idea, each carrying a lifecycle line from seed to adopted or dropped.

The lifecycle: **seed → drafting → stress-testing → adopted | dropped.**

- **seed** — captured, one-line pitch, nothing more owed.
- **drafting** — being worked into a real proposal.
- **stress-testing** — proposal exists; now trying to break it before adopting it.
- **adopted** — it shipped: the idea became an area, a playbook change, or a decision.
  Move the file to archive/ with a pointer to where it landed.
- **dropped** — didn't earn its place. Move to archive/ as-is. Dropping is a fine
  outcome, not a failure.

Rules:

- Each idea file opens with its H1, then a line reading `status: <stage>` — that exact
  spelling, because `os/scripts/gen-status.sh` counts these lines into STATUS.md.
- Advance the stage by editing that line; the file's history is the idea's history.
- /audit flags anything sitting in one stage for more than 60 days. Flagged means
  "decide", not "delete" — advance it or drop it, but decide.

incubator/example-idea.md shows the shape.
