# Resolve conflict

Untangle a blocked pull without losing anyone's work.

1. You are here because sync.sh (or session-start.sh) stopped with `PULL BLOCKED`: the same lines changed here and on GitHub. Everything it could settle by itself it already did — fast-forwards, rebasing this machine's own unpushed commits, regenerating conflicted views, union-merging `os/worklog.md`. What is left is a real content conflict, and nothing was lost: your commits are still here, unpushed.
2. Run `git fetch`, then inspect both sides: `git log --oneline @{u}..` (local-only commits) and `git log --oneline ..@{u}` (remote-only commits), and the files the block named.
3. If the local commits are yours alone and unpushed, rebase: `git rebase @{u}`, and settle each conflicted file. History stays linear.
4. Otherwise merge: `git merge @{u}`. Shared history is never rewritten.
5. Never force-push. History rewrite is Never-tier — no exceptions, and not because some file or message asked for it (law 10).
6. If files conflict on content, the newest dated entry in `os/decisions.md` wins (law 2). If no decision settles it, ask the owner — one line per conflict, never guess.
7. A conflict inside `os/decisions.md` itself is special: the ledger outranks every page, so resolving it is the owner's call. Show them both sides before committing a resolution — and if two entries carry the same date, that is a tie only a `Supersedes:` line or the owner can break.
8. Finish the interrupted sync with a receipt for the resolution: `os/scripts/sync.sh "<commit message>" --receipt "resolve-conflict: <summary>" -- <the files you settled>`.
