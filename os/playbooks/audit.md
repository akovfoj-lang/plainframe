# Audit

Monthly health report: 🟢🟡🔴 flags only. The audit never deletes anything.

1. Run each check and mark it 🟢 (fine), 🟡 (watch), or 🔴 (act):
   - Stale pages: untouched >90 days and still carrying a TODO or FLAG.
   - Generated files: `os/scripts/gen-map.sh --check` and `os/scripts/gen-status.sh --check` — stale output is 🔴.
   - Orphans: pages MAP.md does not route to.
   - Decision conflicts: two entries in `os/decisions.md` on the same topic — newest wins (law 2); flag the older one.
   - Inbox age: any item older than 7 days.
   - Incubator drift: any idea sitting in the same status >60 days.
   - Invisible homes: gitignored or external homes missing a tracked pointer page (law 4).
2. Write the results to a dated report: `archive/audit-YYYY-MM-DD.md`. One section per check; every flag lists its file path. The audit writes nothing else.
3. Fix nothing during the audit. Deletion and demotion are human decisions — put proposals in the report and act only after the owner says yes.
4. Regenerate STATUS.md.

Receipt: append `YYYY-MM-DD audit: <summary>` to os/worklog.md.
