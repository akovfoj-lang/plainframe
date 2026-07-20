# Audit

Monthly health report: 🟢🟡🔴 flags only. The audit never deletes anything.

1. Run each check and mark it 🟢 (fine), 🟡 (watch), or 🔴 (act):
   - Stale pages: untouched >90 days and still carrying a TODO or FLAG.
   - Generated files: `os/scripts/gen-map.sh --check` and `os/scripts/gen-status.sh --check` — stale output is 🔴.
   - Orphans: pages MAP.md does not route to.
   - Decision conflicts: two entries in `os/decisions.md` on the same topic — newest wins (law 2); flag the older one.
   - Future-dated decisions: any `os/decisions.md` entry dated after today. Clock skew or a mis-stated date mints an entry that "wins" forever — 🔴 until the owner corrects it.
   - Unconfirmed decisions: any entry still `**Status:** draft` — void until the owner confirms (law 2). 🔴 if older than 7 days: confirm it or delete it.
   - Superseded ledger entries: any `os/decisions.md` entry named by a newer entry's `Supersedes:` field. `os/decisions.md` is a protected path (law 7): draft a proposed move of each into `archive/decisions-superseded.md` in the report; the owner enacts the actual move, the agent never moves it.
   - Inbox age: any item older than 7 days.
   - Incubator drift: any idea sitting in the same status >60 days.
   - Worklog epoch: `os/worklog.md` has crossed into a new calendar year. Draft rolling the prior year's receipts into `archive/worklog-YYYY.md` in the report; the owner enacts the move.
   - Invisible homes: gitignored or external homes missing a tracked pointer page (law 4).
2. Write the results to a dated report: `archive/audit-YYYY-MM-DD.md`. One section per check; every flag lists its file path. The audit writes nothing else.
3. Fix nothing during the audit. Deletion and demotion are human decisions — put proposals in the report and act only after the owner says yes.
4. Append the receipt (`YYYY-MM-DD audit: <summary>` to os/worklog.md), then regenerate STATUS.md — regeneration last, so STATUS's receipt list already shows this audit.
