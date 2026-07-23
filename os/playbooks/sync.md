# Sync

Pull → commit → push. Satellites first, main last.

Run at session end, after any milestone, and before stepping away for long.

A receipt records an outcome, so it cannot be written truthfully before the
outcome is known — but it also has to ride a commit that gets pushed, or it
just strands the tree dirty again. Two short passes resolve both at once:
sync the real work first, confirm it succeeded, *then* write and sync the
receipt that says so (step 6 below is the whole reason this playbook is two
passes instead of one — PF-015).

1. Check `os/satellites.txt` for satellite repos to include. Comment and blank lines are skipped; so are paths that do not exist.
2. Regenerate before syncing: run `os/scripts/gen-map.sh`, `os/scripts/gen-status.sh`, `os/scripts/gen-commands.sh`. Cheap, idempotent, and required — the pre-commit hook checks what is actually staged (not just the worktree) and fails a commit whose generated files are behind their sources (law 6).
3. Run `os/scripts/sync.sh "<commit message>"`. For each satellite, then for this repo, it: pulls with `--ff-only`, stages everything, commits if the tree is dirty, pushes. **Do not write the worklog receipt yet.**
4. Satellites go first so this repo's pointer pages never claim work a satellite has not pushed yet. Main goes last so the receipts land only after everything they point to is safe.
5. If a pull is blocked, sync.sh stops and says so. Resolve it per `os/playbooks/resolve-conflict.md`, then rerun from step 2.
6. If sync reports `BLOCKED: protected paths changed`, that is law 7 working: a dirty `CLAUDE.md`, `AGENTS.md`, `os/scripts/`, `os/playbooks/`, `os/commands.md`, `.gitignore`, `os/satellites.txt`, or non-draft ledger change may not ride an ordinary sync. Show the owner exactly what changed; with their explicit in-session yes, rerun with a commit message that has `OWNER-CONFIRMED` as its own line — trimmed of surrounding whitespace, that line is nothing else. A mention, a prefix on the same line as the summary, or a negation never counts; only a standalone approval line does:
   ```
   os/scripts/sync.sh "<message>
   OWNER-CONFIRMED"
   ```
   Draft appends to the ledger pass without any token — drafting is the agent's half of the bargain. If sync reports a satellite `ABORTED` for uncommitted work it has not been told to include, review the listed files; with the owner's explicit review, rerun the same way with `SATELLITE-CONFIRMED` as its own line instead. (`git commit --no-verify` also skips the git-level half of this gate — break-glass only, never routine; it leaves no trace that it was used.)
7. Once step 3 reports `OK: sync complete` (the real outcome is now known), append the receipt: `YYYY-MM-DD sync: <summary>` to `os/worklog.md`. If step 3 instead failed or was blocked, do not write a receipt — nothing succeeded yet to record.
8. Regenerate again (`gen-status.sh` at minimum — the receipt just changed `os/worklog.md`, which `STATUS.md`'s "Last 10 receipts" section reads) and run `os/scripts/sync.sh "<commit message>"` a second time to land and push the receipt. This second pass is normally a one-file, one-line commit.

## Scheduling is notify-only (law 8)

9. Never schedule sync.sh itself. A robot on a timer will snapshot half-written pages. Schedule `os/scripts/drift-alert.sh` instead — it only reports dirty trees and unpushed commits, and a human (or an in-session agent) runs /sync deliberately.
10. Hook drift-alert to cron, launchd, or your scheduler. Cron example (uncomment and fix the path to install):

    ```
    # Report drift every day at 09:00 — notify-only, never commits:
    # 0 9 * * * /absolute/path/to/plainframe/os/scripts/drift-alert.sh
    # (macOS: prefer a launchd agent running the same command.)
    ```

Receipt: written in step 7, only after step 3's sync is confirmed to have
succeeded — never before, and never claiming an outcome that has not
happened yet. Step 8 is what gets that receipt pushed.
