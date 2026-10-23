# Audit

Monthly health report: 🟢🟡🔴 flags only. The audit never deletes anything.

1. Run each check and mark it 🟢 (fine), 🟡 (watch), or 🔴 (act). The mark goes in that check's section heading, one per heading: STATUS.md reads verdicts from headings only, so a mark left in body text is never counted. The checks:
   - Stale pages: untouched >90 days and still carrying a TODO or FLAG.
   - Generated files: every `os/scripts/gen-*.sh --check` — gen-map, gen-status, gen-desk, gen-commands, and any generator a clone adds — stale output is 🔴.
   - Reading load: what every session must read before it starts — `wc -c AGENTS.md CLAUDE.md MAP.md`. A total over 13,000 bytes is 🟡, over 16,000 🔴; give the total, each file's size, and the change since the last audit report. Every session pays for every byte, so a file grows unnoticed until someone measures it. For each flag, draft the cut in the report: what moves out, and the one home it moves to (law 3). CLAUDE.md and AGENTS.md are protected, so the owner enacts it.
   - Orphans: pages MAP.md does not route to.
   - Decision conflicts: two entries in `os/decisions.md` on the same topic — newest wins (law 2); flag the older one.
   - Future-dated decisions: any `os/decisions.md` entry dated after today. Clock skew or a mis-stated date mints an entry that "wins" forever — 🔴 until the owner corrects it.
   - Unconfirmed decisions: any entry still `**Status:** draft` — void until the owner confirms (law 2). 🔴 if older than 7 days: confirm it or delete it.
   - Superseded ledger entries: any `os/decisions.md` entry named by a newer entry's `Supersedes:` field. The ledger outranks every page (law 2), so the agent never moves an entry itself: draft a proposed move of each into `archive/decisions-superseded.md` in the report; the owner enacts the actual move.
   - Decision health: every confirmed `os/decisions.md` entry added or changed since the last audit report (the whole ledger on a first run), checked four ways. Proof — the entry, or the commit that confirmed it, carries the owner's own words, or an `OWNER-CONFIRMED` line on that commit; entries that shipped with the Plainframe template count as theirs. None is 🔴: void under law 2, yet sessions follow it. Reach — a one-off pick written as a standing rule, a question read as a ruling, or an agent's reading stated as the owner's: 🔴 if it binds future work, else 🟡. Constitution — an entry that loosens a law, the autonomy table or a protected path: 🔴. Drift, on every confirmed entry, not only new ones — it names a file, script or service that no longer exists, rests on a reason no longer true, or the repo now plainly does the opposite: 🟡. Each flag names the entry by date and title and proposes either "confirm it still stands" or a superseding entry drafted in the report; the agent never edits the ledger during the audit.
   - Inbox age: any item older than 7 days.
   - Incubator drift: any idea sitting in the same status >60 days.
   - Worklog epoch: `os/worklog.md` has crossed into a new calendar year. Draft rolling the prior year's receipts into `archive/worklog-YYYY.md`, plus the pointer line (`YYYY → archive/worklog-YYYY.md`) to add under worklog.md's "Archived epochs" section, in the report; the owner enacts both moves together — a rotation without the pointer line strands those receipts outside law 9.
   - Invisible homes: gitignored or external homes missing a tracked pointer page (law 4).
2. Write the results to a dated report: `archive/audit-YYYY-MM-DD.md`. If that path is already taken (a second audit the same day), don't overwrite it — use `archive/audit-YYYY-MM-DD-2.md`, `-3`, and so on until the name is free; an earlier report is a record, and records survive (law 9). One section per check, its mark in its heading (step 1); every flag lists its file path. The audit writes nothing else.
3. Fix nothing during the audit. Deletion and demotion are human decisions — put proposals in the report and act only after the owner says yes.
4. File it: `os/scripts/sync.sh "audit: monthly report YYYY-MM-DD" --receipt "audit: red n · yellow n · green n; <the red and yellow items in a few words>; report archive/audit-YYYY-MM-DD.md" -- archive/audit-YYYY-MM-DD.md`. Sync regenerates STATUS.md after the receipt, so its audit section already shows this report.

## Running it by itself every month

The audit can run on a schedule, as long as the scheduled run only reports (law 8): a run
nobody is watching must never write, commit or push, and installing the schedule is
Ask-first. In the Claude desktop app, a scheduled task whose prompt is *"In <path to this
repo>, run os/playbooks/audit.md in scheduled mode"*, on the 1st at 10:00, does this:

1. **Report, writing nothing.** Fetch but never pull; if GitHub is ahead, say so at the top,
   since the checks then see an older tree. Run step 1 with read-only commands only
   (`gen-*.sh --check`, `markers.sh`, `drift-alert.sh`, git log, grep). Write no file
   anywhere, fix nothing. If no report is dated in the previous calendar month, open with
   "Last month's audit was never filed."
2. **Ask, so the owner never has to remember.** Post a notification with the counts —
   *"R red, Y yellow, G green. Want to file it?"* — show the full report in the shape
   step 2 describes, and end with the question in bold: **Want to file this audit? Say
   "file it".**
3. **File only on their word.** When the owner says "file it" (or "yes") in that run, they are
   present, so writing is allowed: pull, re-run the checks if anything changed, write the
   report (step 2), and file it (step 4). Still fix nothing.

Receipt: step 4's `--receipt` — `YYYY-MM-DD audit: <summary>` in os/worklog.md.
