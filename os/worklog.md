# Worklog

Dated receipt lines for all work. Work isn't done until its receipt exists here — or, for a
rotated-out year, in the archived epoch file it moved to (law 9). If a session crashes
between doing the work and writing the receipt, the work is treated as not-done. Repeating
it outright is only safe when the action was an idempotent file edit; anything else needs a
check first — never assumed complete from memory.

`os/scripts/gen-status.sh` surfaces the last 10 receipts from this file into `STATUS.md`.
Keep each receipt short: one line per unit of work, newest at the bottom.

Format: `YYYY-MM-DD <command-or-topic>: <one-line summary>` — optionally append
` [evidence: <commit-hash-or-file-path>]` when a receipt can point at exact proof.
Receipts stay the ledger of record either way; evidence is a pointer, not a replacement.

## Archived epochs

None yet. When `/audit` drafts and the owner enacts a yearly rotation (prior year's
receipts moved to `archive/worklog-YYYY.md`), the move adds a line here — `YYYY →
archive/worklog-YYYY.md` — so a rotated year's receipts stay findable and law-9-compliant.

---

2026-07-18 genesis: Plainframe template created
