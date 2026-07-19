# Guide

Give a human or an agent the friendly tour, from zero.

1. Start with the read path: AGENTS.md → CLAUDE.md → MAP.md. That is the whole onboarding — three short files, then MAP routes you to everything else (law 1). Never scan the repo instead.
2. Show the shape: `os/` is the kernel (laws, ledger, playbooks, scripts); `areas/` is the owner's actual life and work; `inbox/` is the dump zone; `incubator/` grows ideas; `archive/` is where things rest.
3. Walk the loop: capture lands in `inbox/` → /sweep routes it → work happens in areas → receipts land in `os/worklog.md` → generators rebuild MAP.md and STATUS.md → the next session reads its way back in. /sync keeps everything pushed; drift-alert watches from outside.
4. Walk the six commands in `os/commands.md`: sweep, sync, audit, ingest, handoff, guide. Each is a thin adapter over one playbook in `os/playbooks/` — the playbook is the truth.
5. Sketch the first week: day one, add an area and drop notes into `inbox/` as they come; run /sweep once a few items pile up; /sync at every session end; put /audit on the monthly line of `os/routine.md`.
6. Show how to add an area: create `areas/<name>/README.md` from `_templates/area.md` — goal, current state, pointers — then regenerate MAP.md so it routes there.
7. Explain why the pieces hold each other up: receipts stop prose from claiming "done"; generated MAP and STATUS cannot lie about the tree; decisions outrank pages, so there is one truth; notify-only automation means a robot never commits a half-thought.
8. End where every session begins: glance at STATUS.md, pick a task, leave a receipt.

No receipt: /guide changes nothing. Receipts record state-changing work (law 9) — logging pure reads would bury the signal under noise.
