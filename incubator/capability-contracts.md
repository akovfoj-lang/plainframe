# capability-contracts

status: seed

**Pitch:** each command declares its expected footprint (which files it may touch) up
front, and /audit diffs the declaration against what actually changed. The shipped kernel
already gates protected paths with the OWNER-CONFIRMED sync check — full per-command
contracts are deferred beyond that.
