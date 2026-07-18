# Sweep

Drain the inbox: classify, route, receipt.

Two beats: PLAN first, APPLY only after the plan is clear. Never jump straight to apply.

## Plan

1. Run `os/scripts/markers.sh` to collect every `EDIT:`, `Q:`, and `IDEA:` marker in the repo
   (markers count only at line start or after `<!-- ` — prose that mentions one doesn't).
2. List every item currently in `inbox/`.
3. Classify each item. One item can split into several pieces — a fact, an idea, and a follow-up can all come out of the same note.
4. Propose a destination for each piece:
   - facts → the owning area page (`areas/<name>/`)
   - ideas → a new seed in `incubator/`
   - assets that live outside git → a pointer page in the home that owns them (law 4)
   - sensitive originals → move outside git first, leave a pointer behind
   - anything unclear → a one-line question to the owner — never guess
5. Show the full routing plan before touching any file.

## Apply

6. Route each piece to its destination.
7. Append a receipt line to `os/worklog.md` for the item.
8. Only now delete the inbox original. This order is crash-safe: if the process dies between step 6 and step 8, the item is still sitting in `inbox/` and gets swept again — nothing is lost, nothing is double-counted.
9. Regenerate `MAP.md` and `STATUS.md`.

Receipt: append `YYYY-MM-DD sweep: <summary>` to os/worklog.md.
