# Workspace

Questions I'm still deciding. One file per question.

This is the missing middle. `inbox/` holds things not yet sorted. `incubator/` holds ideas
that might become something. `os/decisions.md` holds calls already made. Nothing held a
question I'm actively chewing on — so those questions lived in chat and died there.

**Lifecycle:** open → settled.

- **open** — the question is live, options are being weighed.
- **settled** — the call was made. Append the entry to `os/decisions.md` (as a draft; the
  owner confirms it, law 2), then `git mv` this file to `archive/` with a pointer to the
  ledger entry. The thinking stays readable; the decision lives in one home (law 3).

**Rules:**

- Each file opens with its H1, then a line reading `status: open` or `status: settled` —
  that exact spelling, so a generator can count them.
- One question per file. If answering it needs a different question answered first, that
  one gets its own file.
- A question with no options listed isn't ready to be here — it belongs in `inbox/`.
- `_templates/workspace-note.md` is the shape.

**Pointers:**

- Ideas that aren't questions — [incubator/](../incubator/)
- Settled calls — [os/decisions.md](../os/decisions.md)
- The shape — [_templates/workspace-note.md](../_templates/workspace-note.md)
