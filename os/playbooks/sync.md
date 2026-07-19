# Sync

Pull → commit → push. Satellites first, main last.

Run at session end, after any milestone, and before stepping away for long.

1. Check `os/satellites.txt` for satellite repos to include. Comment and blank lines are skipped; so are paths that do not exist.
2. Append the receipt before running anything: `YYYY-MM-DD sync: <summary>` to `os/worklog.md`. The receipt must ride the commit it describes — written after the push it would just dirty the tree again and strand itself unpushed (law 9).
3. Run `os/scripts/sync.sh "<commit message>"`. For each satellite, then for this repo, it: pulls with `--ff-only`, stages everything, commits if the tree is dirty, pushes.
4. Satellites go first so this repo's pointer pages never claim work a satellite has not pushed yet. Main goes last so the receipts land only after everything they point to is safe.
5. If a pull is blocked, sync.sh stops and says so. Resolve it per `os/playbooks/resolve-conflict.md`, then rerun.

## Scheduling is notify-only (law 8)

6. Never schedule sync.sh itself. A robot on a timer will snapshot half-written pages. Schedule `os/scripts/drift-alert.sh` instead — it only reports dirty trees and unpushed commits, and a human (or an in-session agent) runs /sync deliberately.
7. Hook drift-alert to cron, launchd, or your scheduler. Cron example (uncomment and fix the path to install):

   ```
   # Report drift every day at 09:00 — notify-only, never commits:
   # 0 9 * * * /absolute/path/to/plainframe/os/scripts/drift-alert.sh
   # (macOS: prefer a launchd agent running the same command.)
   ```

Receipt: written in step 2, before sync.sh runs — never after the push.
