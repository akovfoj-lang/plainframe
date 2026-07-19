# Decision template

Copy this block into `os/decisions.md` as the newest entry (append at the bottom;
newest still wins by date, not by position — but appending keeps it readable top-to-bottom
in most editors' history view). Fill every field. Delete this comment line before saving.

```markdown
## YYYY-MM-DD: <short decision title>

**Decision:** <the one-sentence call, stated plainly>

**Why:** <the reasoning, one short paragraph — what problem this solves or
what tradeoff it accepts>

**Alternatives considered:** <what else was on the table, and why it lost, one line each>

**Supersedes:** <date + title of the entry this replaces, or: none>

**Status:** confirmed <or: draft — void until the owner confirms in-session, per law 2>
```

Rules for filling it in:
- Date is the day the owner confirmed it, not the day an agent drafted it.
- One decision per entry. If a session produces three decisions, write three entries.
- Never edit an old entry to reverse it — add a new dated entry that supersedes it.
  The newest dated entry wins; history stays intact.
- `Supersedes:` is the explicit precedence edge — and the tiebreaker when two entries
  carry the same date, which date alone cannot order.
- A decision an agent appended but the owner never confirmed is void (law 2). Mark it
  `Status: draft` until confirmed, and don't treat draft entries as binding.
