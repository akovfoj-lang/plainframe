# Sync

Both ways: GitHub's side comes down, this machine's goes up. Satellites first, main last.

**The session does this itself.** After each finished unit of work — anything you would
write a receipt for — and before the session ends, run sync without being asked. The
owner never has to type /sync; when they do, it means "sync everything now" (law 8).

1. Name what you changed. Pass exactly your own paths after `--`. Another session, or the
   owner typing in an editor, may have uncommitted work in this same tree, and sync leaves
   everything outside your paths exactly as it was. Leave the paths off only when the
   owner says to sync everything, or you know you are alone in the tree.
2. Give the work's receipt with `--receipt "<topic>: <one line>"` (the date is added for
   you). Keep it to one short line; the details belong in the page or the commit. A
   receipt with no files behind it (an outside action, a decision recorded elsewhere):
   `--receipt "<line>" --` with nothing after the `--`.
3. Run it:
   ```
   os/scripts/sync.sh "<what you did>" --receipt "<topic>: <one line>" -- <path>...
   ```
   It regenerates the views itself, commits the work and its receipt together, brings
   both sides together and pushes — one commit, nothing else to run. Leave `--receipt`
   off and it writes its own `sync:` line into that commit instead.
4. Read the last line:
   - `OK: synced` or `OK: nothing to sync` — done.
   - `PARTIAL:` (exit 3) — it pushed what it could and says what it left and why. A
     satellite skipped for uncommitted work needs the owner: show them the listed files;
     with their explicit review, rerun with `SATELLITE-CONFIRMED` as its own line in the
     message. Anything else it names, do what the line says.
   - `BLOCKED: protected paths changed` (exit 1) — law 7 working. Show the owner exactly
     what changed; with their explicit in-session yes, rerun with a message that has
     `OWNER-CONFIRMED` as its own line — trimmed of surrounding whitespace, that line is
     nothing else. A mention, a prefix on the same line as the summary, or a negation
     never counts. Write their words, verbatim, into the message too.
   - `PULL BLOCKED` (exit 1) — a real conflict: the same lines changed here and on
     GitHub. Nothing was lost; your commit is still here, unpushed. Resolve per
     `os/playbooks/resolve-conflict.md`, then rerun.

Both ways, on its own: when only GitHub moved, it fast-forwards; when both moved, it
rebases this machine's own unpushed commits on top — the one rewrite the constitution
allows, never a pushed commit, never a merge, never a force-push. A view that conflicts
(MAP, STATUS, DESK, the adapters) is regenerated, and `os/worklog.md` cannot conflict
(`merge=union` in `.gitattributes`). Session start pulls too: `os/scripts/session-start.sh`.

## Scheduling is notify-only (law 8)

5. Never schedule sync.sh itself. A robot on a timer will snapshot half-written pages.
   Schedule `os/scripts/drift-alert.sh` instead — it only reports dirty trees and
   unpushed commits, and an in-session agent syncs deliberately.
6. Hook drift-alert to cron, launchd, or your scheduler. Cron example (uncomment and fix
   the path to install):

    ```
    # Report drift every day at 09:00 — notify-only, never commits:
    # 0 9 * * * /absolute/path/to/plainframe/os/scripts/drift-alert.sh
    # (macOS: prefer a launchd agent running the same command.)
    ```

Receipt: your work's receipt rides in the sync's one commit through `--receipt`; given
none, sync.sh writes a `YYYY-MM-DD sync: …` line there instead. Either way the receipt
and the work reach GitHub together or not at all (PF-015).
