# Contributing to Plainframe

Plainframe is a template: improvements land here and flow into every clone through
[UPGRADING.md](../UPGRADING.md).

- **Kernel changes need the owner's yes.** `CLAUDE.md`, `AGENTS.md`, `os/scripts/`,
  `os/playbooks/` and the other protected paths in CLAUDE.md are gated: a commit touching
  them carries `OWNER-CONFIRMED` as its own line, or the commit-msg and pre-push hooks
  refuse it. Run `os/scripts/doctor.sh --setup` once per clone to wire them.
- **Prove it.** `os/scripts/doctor.sh`, `shellcheck -S warning -x os/scripts/*.sh
  os/scripts/lib/*.sh os/scripts/hooks/*` and `os/scripts/test.sh` must pass, on macOS and
  on Linux; CI runs all three on macOS and Linux (`.github/workflows/check.yml`). A fix to
  a guard or to sync comes with a test in `test.sh` that fails without it.
- **Portable shell only.** Scripts run on macOS's bash 3.2 with BSD tools and on Linux with
  GNU tools: no `sed -i`, no `grep -P`, no `readlink -f`, no associative arrays.
- **Record it.** Add a line to [CHANGELOG.md](../CHANGELOG.md) under the next version, and a
  note in UPGRADING.md when a clone has to do anything by hand.
- **Generated files are never hand-edited** (law 6): MAP.md, STATUS.md, DESK.md and the
  command adapters come from `os/scripts/gen-*.sh`.
