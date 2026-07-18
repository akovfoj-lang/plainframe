# Command manifest — the single source for every tool's adapters.
# os/scripts/gen-commands.sh emits native adapters from this file.
# Format: one `## <name>` block per command with exactly two fields.

## sweep
- desc: Drain the inbox: classify, route, receipt.
- playbook: os/playbooks/sweep.md

## sync
- desc: Pull → commit → push, satellites first.
- playbook: os/playbooks/sync.md

## audit
- desc: Monthly health report: 🟢🟡🔴 flags, no deletions.
- playbook: os/playbooks/audit.md

## ingest
- desc: Deep-read one source and route its contents.
- playbook: os/playbooks/ingest.md

## handoff
- desc: Write the session handoff and chain it.
- playbook: os/playbooks/handoff.md

## guide
- desc: Explain this repo to a human or agent.
- playbook: os/playbooks/guide.md
