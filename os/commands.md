# Command manifest — the single source for every tool's adapters.
# os/scripts/gen-commands.sh emits native adapters from this file.
# Format: one `## <name>` block per command with exactly two fields.

## onboard
- desc: Configure a fresh clone into the owner's own instance.
- playbook: os/playbooks/onboard.md

## sweep
- desc: Drain the inbox and resolve EDIT:/Q:/IDEA: markers, then report what needs you.
- playbook: os/playbooks/sweep.md

## sync
- desc: Sync both ways, satellites first — sessions run it themselves; type it to sync everything now.
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

## level-up
- desc: Weekly 3Ms interview — Mindset, Method, Machine — that ships one automation.
- playbook: os/playbooks/level-up.md

## deepen
- desc: Rewrite a task as the deeper version a top professional would do, then stop for "go".
- playbook: os/playbooks/deepen.md

## grill-me
- desc: Interview the owner one question at a time, saving every answer to a brainstorm file.
- playbook: os/playbooks/grill-me.md
